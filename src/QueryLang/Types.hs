module QueryLang.Types
  ( Step (..)
  , Query (..)
  , Op (..)
  , Condition (..)
  ) where

import Data.Aeson (Value)
import Data.Text (Text)

data Op = Gt | Lt | Ge | Le | Eq | Neq
  deriving (Show, Eq)

data Condition = Condition
  { condField :: Text
  , condOp    :: Op
  , condValue :: Value
  } deriving (Show, Eq)

data Step
  = FieldAccess Text
  | IndexAccess Int
  | Count
  | MapProj [Text]
  | FilterBy Condition
  deriving (Show, Eq)

newtype Query = Query { steps :: [Step] }
  deriving (Show, Eq)
