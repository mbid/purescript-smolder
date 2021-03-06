module Text.Smolder.Markup
  ( MarkupM(..)
  , Markup()
  , Attr(..)
  , EventHandler(..)
  , parent
  , leaf
  , text
  , renderedElement
  , Attribute()
  , class Attributable
  , with
  , attribute
  , (!)
  , optionalWith
  , (!?)
  , EventHandlers(..)
  , class Eventable
  , withEvent
  , on
  , (#!)
  ) where

import Prelude
import DOM.HTML.Types (HTMLElement)
import Data.Bifunctor (class Bifunctor, bimap)
import Data.CatList (CatList)
import Data.Maybe (Maybe(Just, Nothing))
import Data.Monoid (class Monoid, mempty)

data Attr = Attr String String

data EventHandler e = EventHandler String e

instance functorEventHandler ∷ Functor EventHandler where
  map f (EventHandler s e) = EventHandler s (f e)

data MarkupM e a
  = Element String (Maybe (Markup e)) (CatList Attr) (CatList (EventHandler e)) (MarkupM e a)
  | Content String (MarkupM e a)
  | Return a
  | RenderedElement HTMLElement (MarkupM e a)

type Markup e = MarkupM e Unit

parent :: forall e. String -> Markup e -> Markup e
parent el kids = Element el (Just kids) mempty mempty (Return unit)

leaf :: forall e. String -> Markup e
leaf el = Element el Nothing mempty mempty (Return unit)

text :: forall e. String -> Markup e
text s = Content s (Return unit)

renderedElement :: forall e. HTMLElement -> Markup e
renderedElement el = RenderedElement el (Return unit)

instance semigroupMarkupM :: Semigroup (MarkupM e a) where
  append x y = x *> y

instance monoidMarkup :: Monoid (MarkupM e Unit) where
  mempty = Return unit

instance functorMarkupM :: Functor (MarkupM e) where
  map f (Element el kids attrs events rest) = Element el kids attrs events (map f rest)
  map f (Content s rest) = Content s (map f rest)
  map f (Return a) = Return (f a)
  map f (RenderedElement el rest) = RenderedElement el (map f rest)

instance applyMarkupM :: Apply (MarkupM e) where
  apply = ap

instance applicativeMarkupM :: Applicative (MarkupM e) where
  pure = Return

instance bindMarkupM :: Bind (MarkupM e) where
  bind (Element el kids attrs events rest) f = Element el kids attrs events (bind rest f)
  bind (Content s rest) f = Content s (bind rest f)
  bind (Return a) f = f a
  bind (RenderedElement el rest) f = RenderedElement el (bind rest f)

instance monadMarkupM :: Monad (MarkupM e)

instance bifunctorMarkupM ∷ Bifunctor MarkupM where
  bimap f g (Element el kids attrs events rest) =
    Element el (map (bimap f id) kids) attrs (map (map f) events) (bimap f g rest)
  bimap f g (Content s rest) = Content s (bimap f g rest)
  bimap f g (Return a) = Return (g a)
  bimap f g (RenderedElement el rest) = RenderedElement el (bimap f g rest)

data Attribute = Attribute (CatList Attr)

instance semigroupAttribute :: Semigroup Attribute where
  append (Attribute xs) (Attribute ys) = Attribute (append xs ys)

instance monoidAttribute :: Monoid Attribute where
  mempty = Attribute mempty

attribute :: String -> String -> Attribute
attribute key value = Attribute (pure $ Attr key value)

class Attributable a where
  with :: a -> Attribute -> a

instance attributableMarkupM :: Attributable (MarkupM e Unit) where
  with (Element el kids attrs events rest) (Attribute xs) = Element el kids (attrs <> xs) events rest
  with xs _ = xs

instance attributableMarkupMF :: Attributable (MarkupM e Unit -> MarkupM e Unit) where
  with k xs m = k m `with` xs

infixl 4 with as !

optionalWith :: forall h. (Attributable h) => h -> Boolean -> Attribute -> h
optionalWith h c a = if c then h ! a else h

infixl 4 optionalWith as !?

data EventHandlers e = EventHandlers (CatList (EventHandler e))

class Eventable e a | a -> e where
  withEvent :: a -> EventHandlers e -> a

instance eventableMarkupM :: Eventable e (MarkupM e Unit) where
  withEvent (Element el kids attrs events rest) (EventHandlers es) =
    Element el kids attrs (events <> es) rest
  withEvent xs _ = xs

instance eventableMarkupMF :: Eventable e (MarkupM e Unit -> MarkupM e Unit) where
  withEvent k xs m = k m `withEvent` xs

infixl 4 withEvent as #!

on :: forall e. String -> e -> EventHandlers e
on name handler = EventHandlers (pure $ EventHandler name handler)
