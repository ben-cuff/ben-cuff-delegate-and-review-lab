module Main where

import Test.Hspec

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import Data.Text (pack)

import QueryLang.Types (Step (..), Query (..))
import QueryLang.Parser (parseQuery)
import QueryLang.Evaluator (evaluate)
import Formatter (formatValue)

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

spec :: Spec
spec = do
  describe "Parser" $ do
    it "parses a simple field access" $ do
      parseQuery ".name"
        `shouldBe` Right (Query [FieldAccess (pack "name")])

    it "parses an index access" $ do
      parseQuery "[0]"
        `shouldBe` Right (Query [IndexAccess 0])

    it "parses chained field access" $ do
      parseQuery ".a.b"
        `shouldBe` Right (Query
          [ FieldAccess (pack "a")
          , FieldAccess (pack "b")
          ])

    it "parses mixed chained access" $ do
      parseQuery ".items[0].id"
        `shouldBe` Right (Query
          [ FieldAccess (pack "items")
          , IndexAccess 0
          , FieldAccess (pack "id")
          ])

    it "rejects empty query" $ do
      parseQuery "" `shouldBe` Left "Empty query"

    it "parses bracket string access" $ do
      parseQuery "[\"name\"]"
        `shouldBe` Right (Query [FieldAccess (pack "name")])

  describe "Evaluator" $ do
    it "evaluates a field access" $ do
      evaluate (Query [FieldAccess (pack "name")]) sample
        `shouldBe` Right (mkStr "Alice")

    it "evaluates nested field access" $ do
      evaluate
        (Query [FieldAccess (pack "nested"), FieldAccess (pack "key")])
        sample
        `shouldBe` Right (mkStr "value")

    it "evaluates index access on an array" $ do
      evaluate (Query [FieldAccess (pack "items"), IndexAccess 0]) sample
        `shouldBe` Right (mkNum 1)

    it "returns error for missing field" $ do
      evaluate (Query [FieldAccess (pack "missing")]) sample
        `shouldBe` Left "Field not found: \"missing\""

    it "returns error for out-of-bounds index" $ do
      evaluate (Query [FieldAccess (pack "items"), IndexAccess 999]) sample
        `shouldBe` Left "Index out of bounds: 999"

    it "returns error for field access on non-object" $ do
      evaluate (Query [FieldAccess (pack "name"), FieldAccess (pack "x")]) sample
        `shouldBe` Left "Cannot access field on non-object"

  describe "Formatter" $ do
    it "formats a string value" $ do
      formatValue (mkStr "hello") `shouldBe` "\"hello\""

    it "formats a number value" $ do
      formatValue (mkNum 42) `shouldBe` "42"

    it "formats a boolean value" $ do
      formatValue (Bool True) `shouldBe` "true"

    it "formats null" $ do
      formatValue Null `shouldBe` "null"

    it "formats an array" $ do
      formatValue (Array $ V.fromList [mkNum 1, mkNum 2]) `shouldBe` "[1,2]"

main :: IO ()
main = hspec spec
