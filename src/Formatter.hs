module Formatter
  ( formatValue
  ) where

import Data.Aeson (Value, encode)
import qualified Data.ByteString.Lazy.Char8 as BL8

formatValue :: Value -> String
formatValue = BL8.unpack . encode
