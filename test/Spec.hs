module Main where

import Test.Hspec

import ParserSpec (parserSpec)
import EvaluatorSpec (evaluatorSpec)
import FormatterSpec (formatterSpec)

main :: IO ()
main = hspec $ do
  parserSpec
  evaluatorSpec
  formatterSpec
