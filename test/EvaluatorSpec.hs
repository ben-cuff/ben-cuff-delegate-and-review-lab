module EvaluatorSpec (evaluatorSpec) where

import Test.Hspec

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import Data.Text (pack)

import QueryLang.Types (Step (..), Query (..), Op (..), Condition (..), SortDir (..))
import QueryLang.Evaluator (evaluate)
import Shared

evaluatorSpec :: Spec
evaluatorSpec = describe "Evaluator" $ do
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

  it "counts elements in an array" $ do
    evaluate (Query [FieldAccess (pack "items"), Count]) sample
      `shouldBe` Right (mkNum 2)

  it "counts an empty array as 0" $ do
    evaluate (Query [Count]) (Array V.empty)
      `shouldBe` Right (mkNum 0)

  it "counts a single object as 1" $ do
    evaluate (Query [FieldAccess (pack "nested"), Count]) sample
      `shouldBe` Right (mkNum 1)

  it "counts a string value as 1" $ do
    evaluate (Query [FieldAccess (pack "name"), Count]) sample
      `shouldBe` Right (mkNum 1)

  it "projects selected fields from an object" $ do
    evaluate (Query [MapProj [pack "name"]]) sample
      `shouldBe` Right (Object $ KM.fromList
        [(mkKey "name", mkStr "Alice")])

  it "projects fields over an array of objects" $ do
    let arr = Array $ V.fromList
          [ Object $ KM.fromList [(mkKey "a", mkNum 1), (mkKey "b", mkNum 2)]
          , Object $ KM.fromList [(mkKey "a", mkNum 3), (mkKey "b", mkNum 4)]
          ]
    evaluate (Query [MapProj [pack "a"]]) arr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "a", mkNum 1)]
        , Object $ KM.fromList [(mkKey "a", mkNum 3)]
        ])

  it "projects over an empty array" $ do
    evaluate (Query [MapProj [pack "a"]]) (Array V.empty)
      `shouldBe` Right (Array V.empty)

  it "omits missing projected fields silently" $ do
    evaluate (Query [MapProj [pack "missing"]]) sample
      `shouldBe` Right (Object KM.empty)

  it "errors on map projection of non-object" $ do
    evaluate (Query [MapProj [pack "x"]]) (mkStr "hello")
      `shouldBe` Left "Cannot project fields on non-object/non-array"

  it "filters array elements by condition" $ do
    evaluate (Query [FilterBy (Condition (pack "price") Gt (mkNum 9))]) itemsArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "id", mkNum 1), (mkKey "price", mkNum 10)]
        , Object $ KM.fromList [(mkKey "id", mkNum 2), (mkKey "price", mkNum 20)]
        ])

  it "filters with >= operator" $ do
    evaluate (Query [FilterBy (Condition (pack "price") Ge (mkNum 10))]) itemsArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "id", mkNum 1), (mkKey "price", mkNum 10)]
        , Object $ KM.fromList [(mkKey "id", mkNum 2), (mkKey "price", mkNum 20)]
        ])

  it "filters with <= operator" $ do
    evaluate (Query [FilterBy (Condition (pack "price") Le (mkNum 10))]) itemsArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "id", mkNum 1), (mkKey "price", mkNum 10)]
        , Object $ KM.fromList [(mkKey "id", mkNum 3), (mkKey "price", mkNum 5)]
        ])

  it "filters with == operator" $ do
    evaluate (Query [FilterBy (Condition (pack "id") Eq (mkNum 2))]) itemsArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "id", mkNum 2), (mkKey "price", mkNum 20)]
        ])

  it "filters with != operator" $ do
    evaluate (Query [FilterBy (Condition (pack "id") Neq (mkNum 2))]) itemsArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "id", mkNum 1), (mkKey "price", mkNum 10)]
        , Object $ KM.fromList [(mkKey "id", mkNum 3), (mkKey "price", mkNum 5)]
        ])

  it "filters with missing field returns empty" $ do
    evaluate (Query [FilterBy (Condition (pack "missing") Gt (mkNum 0))]) itemsArr
      `shouldBe` Right (Array V.empty)

  it "filters an empty array returns empty" $ do
    evaluate (Query [FilterBy (Condition (pack "x") Gt (mkNum 0))]) (Array V.empty)
      `shouldBe` Right (Array V.empty)

  it "errors filtering a non-array" $ do
    evaluate (Query [FilterBy (Condition (pack "x") Eq (mkNum 1))]) sample
      `shouldBe` Left "Cannot filter non-array"

  it "sorts ascending by field" $ do
    evaluate (Query [SortBy (pack "age") Asc]) sortArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "name", mkStr "alice"),   (mkKey "age", mkNum 25)]
        , Object $ KM.fromList [(mkKey "name", mkStr "charlie"), (mkKey "age", mkNum 30)]
        , Object $ KM.fromList [(mkKey "name", mkStr "bob"),     (mkKey "age", mkNum 35)]
        ])

  it "sorts descending by field" $ do
    evaluate (Query [SortBy (pack "age") Desc]) sortArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "name", mkStr "bob"),     (mkKey "age", mkNum 35)]
        , Object $ KM.fromList [(mkKey "name", mkStr "charlie"), (mkKey "age", mkNum 30)]
        , Object $ KM.fromList [(mkKey "name", mkStr "alice"),   (mkKey "age", mkNum 25)]
        ])

  it "sorts strings lexicographically" $ do
    evaluate (Query [SortBy (pack "name") Asc]) sortArr
      `shouldBe` Right (Array $ V.fromList
        [ Object $ KM.fromList [(mkKey "name", mkStr "alice"),   (mkKey "age", mkNum 25)]
        , Object $ KM.fromList [(mkKey "name", mkStr "bob"),     (mkKey "age", mkNum 35)]
        , Object $ KM.fromList [(mkKey "name", mkStr "charlie"), (mkKey "age", mkNum 30)]
        ])

  it "sorts an empty array" $ do
    evaluate (Query [SortBy (pack "x") Asc]) (Array V.empty)
      `shouldBe` Right (Array V.empty)

  it "errors sorting a non-array" $ do
    evaluate (Query [SortBy (pack "x") Asc]) (mkStr "hello")
      `shouldBe` Left "Cannot sort non-array"

  it "errors sorting values of different types" $ do
    let mixed = Array $ V.fromList
          [ Object $ KM.fromList [(mkKey "val", mkNum 1)]
          , Object $ KM.fromList [(mkKey "val", mkStr "two")]
          ]
    evaluate (Query [SortBy (pack "val") Asc]) mixed
      `shouldBe` Left "Cannot sort values of different types"
