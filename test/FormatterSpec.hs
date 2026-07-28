module FormatterSpec (formatterSpec) where

import Test.Hspec

import Data.Aeson (Value (..))
import qualified Data.Vector as V

import Formatter (formatValue)
import Shared

formatterSpec :: Spec
formatterSpec = describe "Formatter" $ do
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
