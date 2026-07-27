module Main where

import System.Environment (getArgs)
import qualified Data.ByteString.Lazy as BL
import Data.Aeson (eitherDecode)
import QueryLang.Parser (parseQuery)
import QueryLang.Evaluator (evaluate)
import Formatter (formatValue)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [query, filepath] -> run query filepath
    _                 -> putStrLn "Usage: json-query <query> <json-file>"

run :: String -> FilePath -> IO ()
run queryStr path = do
  content <- BL.readFile path
  case eitherDecode content of
    Left err  -> putStrLn $ "Error: Invalid JSON - " <> err
    Right val -> case parseQuery queryStr of
      Left err      -> putStrLn $ "Error: Invalid query - " <> err
      Right query   -> case evaluate query val of
        Left err    -> putStrLn $ "Error: " <> err
        Right result -> putStrLn $ formatValue result
