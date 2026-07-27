module QueryLang.Evaluator
  ( evaluate
  ) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import QueryLang.Types (Step (..), Query (..))

evaluate :: Query -> Value -> Either String Value
evaluate (Query []) v = Right v
evaluate (Query (step : rest)) v = case step of
  FieldAccess field -> case v of
    Object obj -> case KM.lookup (Key.fromText field) obj of
      Just val -> evaluate (Query rest) val
      Nothing  -> Left $ "Field not found: " <> show field
    _ -> Left "Cannot access field on non-object"
  IndexAccess idx -> case v of
    Array arr -> case arr V.!? idx of
      Just val -> evaluate (Query rest) val
      Nothing  -> Left $ "Index out of bounds: " <> show idx
    _ -> Left "Cannot index non-array"
