module ParserSpec (parserSpec) where

import Test.Hspec

import Data.Aeson (Value (..))
import Data.Text (pack)

import QueryLang.Types (Step (..), Query (..), Op (..), Condition (..), SortDir (..))
import QueryLang.Parser (parseQuery)
import Shared

parserSpec :: Spec
parserSpec = describe "Parser" $ do
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

  it "parses count" $ do
    parseQuery "count"
      `shouldBe` Right (Query [Count])

  it "parses count with pipe" $ do
    parseQuery "| count"
      `shouldBe` Right (Query [Count])

  it "parses count after navigation" $ do
    parseQuery ".items count"
      `shouldBe` Right (Query [FieldAccess (pack "items"), Count])

  it "parses count after pipe" $ do
    parseQuery ".items | count"
      `shouldBe` Right (Query [FieldAccess (pack "items"), Count])

  it "parses map projection" $ do
    parseQuery "{name, price}"
      `shouldBe` Right (Query [MapProj [pack "name", pack "price"]])

  it "parses map projection with trailing comma" $ do
    parseQuery "{name,}"
      `shouldBe` Right (Query [MapProj [pack "name"]])

  it "parses map projection after navigation" $ do
    parseQuery ".items{name, price}"
      `shouldBe` Right (Query [FieldAccess (pack "items"), MapProj [pack "name", pack "price"]])

  it "parses filter with number comparison" $ do
    parseQuery "[?price > 10]"
      `shouldBe` Right (Query [FilterBy (Condition (pack "price") Gt (mkNum 10))])

  it "parses filter with string comparison" $ do
    parseQuery "[?name == \"Alice\"]"
      `shouldBe` Right (Query [FilterBy (Condition (pack "name") Eq (mkStr "Alice"))])

  it "parses filter after navigation" $ do
    parseQuery ".items[?price >= 5]"
      `shouldBe` Right (Query [FieldAccess (pack "items"), FilterBy (Condition (pack "price") Ge (mkNum 5))])

  it "parses filter with != operator" $ do
    parseQuery "[?status != \"done\"]"
      `shouldBe` Right (Query [FilterBy (Condition (pack "status") Neq (mkStr "done"))])

  it "parses filter with boolean value" $ do
    parseQuery "[?active == true]"
      `shouldBe` Right (Query [FilterBy (Condition (pack "active") Eq (Bool True))])

  it "parses filter with null value" $ do
    parseQuery "[?value == null]"
      `shouldBe` Right (Query [FilterBy (Condition (pack "value") Eq Null)])

  it "parses sort ascending" $ do
    parseQuery "sort(price)"
      `shouldBe` Right (Query [SortBy (pack "price") Asc])

  it "parses sort descending" $ do
    parseQuery "sort(price desc)"
      `shouldBe` Right (Query [SortBy (pack "price") Desc])

  it "parses sort with pipe" $ do
    parseQuery "| sort(price)"
      `shouldBe` Right (Query [SortBy (pack "price") Asc])

  it "parses sort after navigation" $ do
    parseQuery ".items sort(price)"
      `shouldBe` Right (Query [FieldAccess (pack "items"), SortBy (pack "price") Asc])
