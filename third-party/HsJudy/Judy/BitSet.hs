module Judy.BitSet(
    new,
    set,
    get,
    swapBitSets,
    toListIO,
    setList,
    clear,
    fromListIO,
    freezeBitSet,
    member,
    fromList,
    toList
    )


    where


import Data.Typeable
import Foreign.ForeignPtr
import Foreign.Marshal.Alloc
import Foreign.Storable
import Foreign.Ptr
import System.IO.Unsafe

import Judy.Private
import Judy.Freeze


--type ForeignPtr a = Ptr a
--withForeignPtr a action = action a
--mallocForeignPtr = malloc
--addForeignPtrFinalizer _ _ = return ()

newtype BitSet = BitSet (ForeignPtr Judy)
    deriving(Eq,Ord,Typeable)


instance Show BitSet where
    show (BitSet j) = "<BitSet " ++ show j ++ ">"



-- | O(1) - swap contents of two bitsets
swapBitSets :: BitSet -> BitSet -> IO ()
swapBitSets (BitSet bs1) (BitSet bs2) = do
    withForeignPtr bs1 $ \p1 ->  do
        withForeignPtr bs2 $ \p2 ->  do
            v1 <- peek p1
            v2 <- peek p2
            poke p1 v2
            poke p2 v1

new :: IO BitSet
new = do
    fp <- mallocForeignPtr
    addForeignPtrFinalizer judy1_free_ptr fp
    withForeignPtr fp $ flip poke nullPtr
    return $ BitSet fp


-- | set a bit and return its old state
set :: BitSet -> WordPtr -> Bool -> IO Bool
set (BitSet j) wp True = withForeignPtr j $ \j ->  do
    r <- judy1Set j wp judyError
    return $ r == 0
set (BitSet j) wp False = withForeignPtr j $ \j -> do
    r <- judy1Unset j wp judyError
    return $ r /= 0

{-# INLINE get #-}
get :: BitSet -> WordPtr -> IO Bool
get (BitSet j) wp = do
    jj <- withForeignPtr j peek
    r <- judy1Test jj wp judyError
    return $ r /= 0

toListIO :: BitSet -> IO [WordPtr]
toListIO (BitSet j) = do
    jj <- withForeignPtr j peek
    alloca $ \wp -> do
        poke wp (-1)
        let f 0 xs = return xs
            f _ xs = do
                v <- peek wp
                r <- judy1Prev jj wp judyError
                f r (v:xs)
        r <- judy1Last jj wp judyError
        f r []

setList :: [WordPtr] -> Bool -> BitSet  ->  IO ()
setList ws True (BitSet bs) = withForeignPtr bs $ \j -> mapM_ (\w -> judy1Set j w judyError) ws
setList ws False (BitSet bs) = withForeignPtr bs $ \j -> mapM_ (\w -> judy1Unset j w judyError) ws

-- | completely clear a BitSet
clear :: BitSet -> IO ()
clear (BitSet j) = withForeignPtr j $ \j -> judy1FreeArray j judyError >> return ()

fromListIO :: [WordPtr] -> IO BitSet
fromListIO ws = do
    bs <- new
    setList ws True bs
    return bs

-- Pure access routines

-- | create a frozen, immutable version of a bitset, the original mutable version is cleared.
freezeBitSet :: BitSet -> IO (Frozen BitSet)
freezeBitSet bs = do
    nbs <- new
    swapBitSets bs nbs
    return (Frozen nbs)

member :: WordPtr -> Frozen BitSet -> Bool
member wp (Frozen bs) = unsafePerformIO $ get bs wp

fromList :: [WordPtr] -> Frozen BitSet
fromList ws = Frozen $ unsafePerformIO $ do
    bs <- new
    setList ws True bs
    return bs

toList :: Frozen BitSet -> [WordPtr]
toList = toListFrom 0


toListFrom :: WordPtr -> Frozen BitSet -> [WordPtr]
toListFrom iwp (Frozen (BitSet bs)) = unsafePerformIO $ do
        jj <- withForeignPtr bs peek
        (r,v) <- alloca $ \wp -> do
            poke wp iwp
            r <- judy1First jj wp judyError
            v <- peek wp
            return (r,v)
        let f 0 _ = []
            f _ v = v:unsafePerformIO (g v)
            g v = do
                (r,v) <- alloca $ \wp -> do
                    poke wp v
                    r <- judy1Next jj wp judyError
                    v <- peek wp
                    touchForeignPtr bs
                    return (r,v)
                return (f r v)
        return (f r v)


toRevList :: Frozen BitSet -> [WordPtr]
toRevList = toRevListFrom (-1)

toRevListFrom :: WordPtr -> Frozen BitSet -> [WordPtr]
toRevListFrom iwp (Frozen (BitSet bs)) = unsafePerformIO $ do
    withForeignPtr bs $ \j -> do
        jj <- peek j
        (r,v) <- alloca $ \wp -> do
            poke wp iwp
            r <- judy1Last jj wp judyError
            v <- peek wp
            return (r,v)
        let f 0 _ = []
            f _ v = v:unsafePerformIO (g v)
            g v = do
                (r,v) <- alloca $ \wp -> do
                    poke wp v
                    r <- judy1Prev jj wp judyError
                    v <- peek wp
                    touchForeignPtr bs
                    return (r,v)
                return (f r v)
        return (f r v)


instance Freezable BitSet where
    freeze = freezeBitSet
