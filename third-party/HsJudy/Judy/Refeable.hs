{-# OPTIONS -fallow-undecidable-instances -fallow-incoherent-instances #-}

module Judy.Refeable (
    Refeable (..),
) where

import Foreign.Ptr
import Foreign.StablePtr

import Judy.Private


-- FIXME: It results in an illegal instruction if I take the "Dummy a"
-- out of "Refeable a" context. Maybe something arch related, dunno. =P

class Dummy a
instance Dummy a

class Refeable a where
    toRef :: a -> IO Value
    fromRef :: Value -> IO a
    --freeRef :: Value -> IO ()
    --For using in finalizers

instance Dummy a => Refeable a where
--instance Refeable a where
    toRef a = do
        a' <- newStablePtr a
        return (ptrToWordPtr (castStablePtrToPtr a'))
    fromRef v = do
        a <- deRefStablePtr (castPtrToStablePtr (wordPtrToPtr v))
        return a


instance Refeable Int where
    toRef i = return $ toEnum i
    fromRef v = return $ fromEnum v
