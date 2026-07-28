module Shared where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import Data.Text (pack)

mkStr :: String -> Value
mkStr = String . pack

mkNum :: Int -> Value
mkNum = Number . fromIntegral

mkKey :: String -> Key.Key
mkKey = Key.fromText . pack

sample :: Value
sample = Object $ KM.fromList
  [ (mkKey "name",   mkStr "Alice")
  , (mkKey "age",    mkNum 30)
  , (mkKey "items",  Array $ V.fromList [mkNum 1, mkNum 2])
  , (mkKey "nested", Object $ KM.fromList
      [(mkKey "key", mkStr "value")]
    )
  ]

itemsArr :: Value
itemsArr = Array $ V.fromList
  [ Object $ KM.fromList [(mkKey "id", mkNum 1), (mkKey "price", mkNum 10)]
  , Object $ KM.fromList [(mkKey "id", mkNum 2), (mkKey "price", mkNum 20)]
  , Object $ KM.fromList [(mkKey "id", mkNum 3), (mkKey "price", mkNum 5)]
  ]

sortArr :: Value
sortArr = Array $ V.fromList
  [ Object $ KM.fromList [(mkKey "name", mkStr "charlie"), (mkKey "age", mkNum 30)]
  , Object $ KM.fromList [(mkKey "name", mkStr "alice"),   (mkKey "age", mkNum 25)]
  , Object $ KM.fromList [(mkKey "name", mkStr "bob"),     (mkKey "age", mkNum 35)]
  ]
