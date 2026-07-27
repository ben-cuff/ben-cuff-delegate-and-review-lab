module QueryLang.Types
  ( Step (..)
  , Query (..)
  ) where

import Data.Text (Text)

data Step
  = FieldAccess Text
  | IndexAccess Int
  | Count
  deriving (Show, Eq)

newtype Query = Query { steps :: [Step] }
  deriving (Show, Eq)
