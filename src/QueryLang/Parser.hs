module QueryLang.Parser
  ( parseQuery
  ) where

import Control.Monad (when)
import Data.Aeson (Value (..))
import Data.Char (isAlphaNum, isDigit, isSpace)
import Data.List (isPrefixOf, stripPrefix)
import Data.Text (pack)
import QueryLang.Types (Step (..), Query (..), Op (..), Condition (..), SortDir (..))

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
parseSteps ('[':s) = case s of
  '?':s' -> do
    (step, rest) <- parseFilter s'
    (step :) <$> parseSteps rest
  _      -> do
    (step, rest) <- bracket s
    (step :) <$> parseSteps rest
parseSteps ('{':s) = do
  (step, rest) <- parseMapProj s
  (step :) <$> parseSteps rest
parseSteps ('|':s) = parseSteps (dropWhile isSpace s)
parseSteps s = case parseOperation s of
  Right (step, rest) -> (step :) <$> parseSteps rest
  Left _             -> Left $ "Unexpected character: " <> [head s]

isIdentChar :: Char -> Bool
isIdentChar c = isAlphaNum c || c == '_' || c == '-'

fieldName :: String -> Either String (String, String)
fieldName "" = Left "Expected field name after '.'"
fieldName s  = case span isIdentChar s of
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

parseFilter :: String -> Either String (Step, String)
parseFilter s = do
  let s' = dropWhile isSpace s
      (field, s1) = span isIdentChar s'
  when (null field) (Left "Expected field name in filter condition")
  let s2 = dropWhile isSpace s1
  (op, s3) <- parseOp s2
  let s4 = dropWhile isSpace s3
  (val, s5) <- parseValue s4
  let s6 = dropWhile isSpace s5
  case s6 of
    ']':rest -> Right (FilterBy (Condition (pack field) op val), rest)
    _        -> Left "Expected ']' after filter condition"

parseOp :: String -> Either String (Op, String)
parseOp s
  | ">=" `isPrefixOf` s = Right (Ge, drop 2 s)
  | "<=" `isPrefixOf` s = Right (Le, drop 2 s)
  | "==" `isPrefixOf` s = Right (Eq, drop 2 s)
  | "!=" `isPrefixOf` s = Right (Neq, drop 2 s)
  | '>' : rest <- s     = Right (Gt, rest)
  | '<' : rest <- s     = Right (Lt, rest)
  | otherwise           = Left $ "Unknown operator: " <> take 2 s

parseValue :: String -> Either String (Value, String)
parseValue ('"':s) = do
  let (str, rest) = break (== '"') s
  case rest of
    '"':cs -> Right (String (pack str), cs)
    _      -> Left "Unterminated string value"
parseValue s
  | "true"  `isPrefixOf` s = Right (Bool True,  drop 4 s)
  | "false" `isPrefixOf` s = Right (Bool False, drop 5 s)
  | "null"  `isPrefixOf` s = Right (Null,       drop 4 s)
parseValue s@(c:_)
  | isDigit c || c == '-' = do
      let (numStr, rest) = span (\c -> isDigit c || c == '.') s
      case reads numStr of
        [(n, "")] -> Right (Number n, rest)
        _         -> Left $ "Invalid number: " <> numStr
parseValue s = Left $ "Unexpected value: " <> take 10 s

parseOperation :: String -> Either String (Step, String)
parseOperation s
  | Just rest <- stripPrefix "count" s
  = Right (Count, dropWhile isSpace rest)
  | Just afterSort <- stripPrefix "sort" s
  = parseSort afterSort
  | otherwise
  = Left "Not a valid operation"

parseSort :: String -> Either String (Step, String)
parseSort s = do
  let s' = dropWhile isSpace s
  case s' of
    '(':s'' -> do
      let s''' = dropWhile isSpace s''
          (field, afterField) = span isIdentChar s'''
      when (null field) (Left "Expected field name in sort")
      let afterField' = dropWhile isSpace afterField
          (dirToken, afterDir) = break (== ')') afterField'
          dir = dropWhile isSpace dirToken
      case afterDir of
        ')':cs -> do
          let rest = dropWhile isSpace cs
          case dir of
            ""     -> Right (SortBy (pack field) Asc, rest)
            "asc"  -> Right (SortBy (pack field) Asc, rest)
            "desc" -> Right (SortBy (pack field) Desc, rest)
            _      -> Left $ "Unknown sort direction: " <> dir
        _ -> Left "Expected ')' after sort field"
    _ -> Left "Expected '(' after 'sort'"
