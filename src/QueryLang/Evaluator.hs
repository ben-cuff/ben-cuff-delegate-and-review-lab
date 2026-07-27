module QueryLang.Evaluator
  ( evaluate
  ) where

import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import QueryLang.Types (Step (..), Query (..), Op (..), Condition (..))

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
  Count -> case v of
    Array arr -> evaluate (Query rest) (Number (fromIntegral (V.length arr)))
    _         -> evaluate (Query rest) (Number 1)
  MapProj fields -> case v of
    Object obj ->
      let selected = KM.filterWithKey (\k _ -> Key.toText k `elem` fields) obj
      in evaluate (Query rest) (Object selected)
    Array arr -> do
      mapped <- traverse projectObj (V.toList arr)
      evaluate (Query rest) (Array (V.fromList mapped))
    _ -> Left "Cannot project fields on non-object/non-array"
    where
      projectObj (Object obj) = Right $ Object $
        KM.filterWithKey (\k _ -> Key.toText k `elem` fields) obj
      projectObj _ = Left "Cannot project fields on non-object element"
  FilterBy cond -> case v of
    Array arr -> do
      let filtered = V.filter (checkCondition cond) arr
      evaluate (Query rest) (Array filtered)
    _ -> Left "Cannot filter non-array"

checkCondition :: Condition -> Value -> Bool
checkCondition (Condition field op val) element = case element of
  Object obj -> case KM.lookup (Key.fromText field) obj of
    Just fieldVal -> applyOp op (compareValues fieldVal val)
    Nothing       -> False
  _ -> False

compareValues :: Value -> Value -> Ordering
compareValues (Number a) (Number b) = compare a b
compareValues (String a) (String b) = compare a b
compareValues (Bool a)   (Bool b)   = compare a b
compareValues Null       Null       = EQ
compareValues _          _          = EQ

applyOp :: Op -> Ordering -> Bool
applyOp Gt  GT = True
applyOp Lt  LT = True
applyOp Ge  GT = True
applyOp Ge  EQ = True
applyOp Le  LT = True
applyOp Le  EQ = True
applyOp Eq  EQ = True
applyOp Neq EQ = False
applyOp Neq _  = True
applyOp _   _  = False
