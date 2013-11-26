{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE Rank2Types #-}

module Unison.Syntax.Term where

import Control.Applicative
import Control.Lens
import Data.Foldable
import Data.Maybe
import Unison.Syntax.Literal
import Unison.Syntax.Var as V
import Unison.Syntax.DeBruijn as D

type ClosedTerm k t = forall v. Term k t v

-- | Terms with free variables in `v`, type annotations in `t`,
-- and literals in `k`.
data Term k t v
  = Var (Var v) -- a variable is either free, or bound
  | Lit k
  | App (Term k t v) (Term k t v)
  | Ann (Term k t v) t
  | Lam (Term k t v)
  deriving (Eq,Ord,Show,Functor,Foldable,Traversable)

abstract1 :: Eq v => v -> Term k t v -> Maybe (Term k t v2)
abstract1 v = collect go where
  go v2 | v2 == v = Just (Var V.bound1)
  go _ = Nothing

abstract :: Eq v => v -> Term k t v -> ([v], Term k t v)
abstract v = collect go where
  go v2 | v2 == v = ([], Var V.bound1)
  go v2 = ([v2], Var (Free v2))

ap1 :: Term k t v -> Term k t v -> Maybe (Term k t v)
ap1 (Lam body) t = Just (subst1 body t)
ap1 _ _ = Nothing

bound1 :: Term k t v
bound1 = Var V.bound1

closed :: Term k t v -> Maybe (Term k t v2)
closed = traverse (const Nothing)

collect :: Applicative f
       => (v -> f (Term k t v2))
       -> Term k t v
       -> f (Term k t v2)
collect f = go where
  go e = case e of
    Var (Free v) -> f v
    Var (Bound ind) -> pure (Var (Bound ind))
    Lit l -> pure (Lit l) -- not clear why can't just recyle LHS
    App fn arg -> App <$> go fn <*> go arg
    Ann e' t -> Ann <$> go e' <*> pure t
    Lam body -> Lam <$> go body

lam1 :: (forall v . Term k t v -> Term k t v) -> Term k t v2
lam1 f = Lam . fromJust . abstract1 () . f $ Var (Free ())

subst1 :: Term k t v -> Term k t v -> Term k t v
subst1 = go D.bound1 where
  go ind body e = case body of
    Var (Bound i) | i == ind -> e
    Var _ -> body
    Lit _ -> body
    App f arg -> App (go ind f e) (go ind arg e)
    Ann body' t -> Ann (go ind body' e) t
    Lam body' -> Lam (go (D.succ ind) body' e)

vars :: Term k t v -> [v]
vars = toList
