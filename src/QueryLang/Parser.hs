module QueryLang.Parser
  ( parseQuery
  ) where

import Data.Char (isAlphaNum, isDigit, isSpace)
import Data.List (stripPrefix)
import Data.Text (pack)
import QueryLang.Types (Step (..), Query (..))

parseQuery :: String -> Either String Query
parseQuery "" = Left "Empty query"
parseQuery s  = fmap Query (parseSteps s)

parseSteps :: String -> Either String [Step]
parseSteps "" = Right []
parseSteps s
  | isSpace (head s) = parseSteps (dropWhile isSpace s)
parseSteps ('.':s) = do
  (field, rest) <- fieldName s
  (FieldAccess (pack field) :) <$> parseSteps rest
parseSteps ('[':s) = do
  (step, rest) <- bracket s
  (step :) <$> parseSteps rest
parseSteps ('{':s) = do
  (step, rest) <- parseMapProj s
  (step :) <$> parseSteps rest
parseSteps ('|':s) = parseSteps (dropWhile isSpace s)
parseSteps s = case parseOperation s of
  Right (step, rest) -> (step :) <$> parseSteps rest
  Left _             -> Left $ "Unexpected character: " <> [head s]

fieldName :: String -> Either String (String, String)
fieldName "" = Left "Expected field name after '.'"
fieldName s  = case span (\c -> isAlphaNum c || c == '_' || c == '-') s of
  ("", _) -> Left "Expected field name"
  p       -> Right p

bracket :: String -> Either String (Step, String)
bracket ('"':s) = do
  let (key, rest) = break (== '"') s
  case rest of
    '"':']':cs -> Right (FieldAccess (pack key), cs)
    '"':_      -> Left "Expected ']' after string key"
    _          -> Left "Unterminated string in bracket access"
bracket s = case span isDigit s of
  (digits, ']':cs) | not (null digits) -> Right (IndexAccess (read digits), cs)
  (_,     _)                           -> Left "Expected integer index followed by ']'"

parseMapProj :: String -> Either String (Step, String)
parseMapProj s = do
  let s' = dropWhile isSpace s
      (content, rest) = break (== '}') s'
  case rest of
    '}':after -> Right (MapProj (map pack (words (map (\c -> if c == ',' then ' ' else c) content))), after)
    _         -> Left "Unterminated map projection, expected '}'"

parseOperation :: String -> Either String (Step, String)
parseOperation s
  | Just rest <- stripPrefix "count" s
  = Right (Count, dropWhile isSpace rest)
  | otherwise
  = Left "Not a valid operation"
