module QueryLang.Evaluator
  ( evaluate
  ) where

import Control.Monad (unless)
import Data.Aeson (Value (..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KM
import qualified Data.Vector as V
import Data.List (sortBy)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import QueryLang.Types (Step (..), Query (..), Op (..), Condition (..), SortDir (..))

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
  SortBy field dir -> case v of
    Array arr -> do
      let extracted = V.map (extractField field) arr
      sorted <- sortArray dir extracted arr
      evaluate (Query rest) (Array sorted)
    _ -> Left "Cannot sort non-array"

checkCondition :: Condition -> Value -> Bool
checkCondition (Condition field op val) element = case element of
  Object obj -> case KM.lookup (Key.fromText field) obj of
    Just fieldVal -> case compareValues fieldVal val of
      Just ord -> applyOp op ord
      Nothing  -> False
    Nothing -> False
  _ -> False

compareValues :: Value -> Value -> Maybe Ordering
compareValues (Number a) (Number b) = Just (compare a b)
compareValues (String a) (String b) = Just (compare a b)
compareValues (Bool a)   (Bool b)   = Just (compare a b)
compareValues Null       Null       = Just EQ
compareValues _          _          = Nothing

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

extractField :: Text -> Value -> Value
extractField field (Object obj) = fromMaybe Null (KM.lookup (Key.fromText field) obj)
extractField _ _ = Null

sortArray :: SortDir -> V.Vector Value -> V.Vector Value -> Either String (V.Vector Value)
sortArray dir keys vals = do
  let nonNull = V.filter (/= Null) keys
  unless (V.null nonNull) $ do
    let t = valueTag (V.head nonNull)
        allSame = V.all (\v -> valueTag v == t) nonNull
    unless allSame (Left "Cannot sort values of different types")
  let pairs = V.toList (V.zip keys vals)
      cmp (k1, _) (k2, _) = fromMaybe EQ (compareValues k1 k2)
      sorted = case dir of
        Asc  -> sortBy cmp pairs
        Desc -> sortBy (flip cmp) pairs
  Right (V.fromList (map snd sorted))

valueTag :: Value -> Int
valueTag (Object _) = 0
valueTag (Array _)  = 1
valueTag (String _) = 2
valueTag (Number _) = 3
valueTag (Bool _)   = 4
valueTag Null       = 5
