{-# OPTIONS_GHC -fglasgow-exts -cpp -fvia-C -fno-full-laziness -fno-cse #-}
#if !defined(PUGS_HAVE_PARROT)
##undef PUGS_HAVE_POSIX
##include "../pugs_config.h"

module Pugs.Embed.Parrot where
import Data.IORef
import System.Cmd
import System.Process
import System.Directory
import System.IO
import System.IO.Unsafe
import Data.Maybe
import Control.Monad
import Pugs.Compat (getEnv)
import Pugs.Internals (encodeUTF8)

findExecutable' :: String -> IO (Maybe FilePath)
findExecutable' cmd = do
    dir <- getEnv "PARROT_PATH"
    if isJust dir then (do
        rv  <- findExecutableInDirectory (fromJust dir) cmd
        if isJust rv then return rv else findExecutable'') else do
    findExecutable''
    where
    findExecutable'' = do
        rv  <- findExecutable cmd
        if isJust rv then return rv else do
        cwd <- getCurrentDirectory
        rv  <- findExecutableInDirectory cwd cmd
        if isJust rv then return rv else do
        return Nothing

findExecutableInDirectory :: FilePath -> FilePath -> IO (Maybe FilePath)
findExecutableInDirectory dir cmd = do
##ifdef PUGS_HAVE_POSIX
    let file = dir ++ ('/':cmd)
##else
    let file = dir ++ ('\\':cmd) ++ ".exe"
##endif
    ok  <- doesFileExist file
    return $ if ok then Just file else Nothing

findParrot :: IO FilePath
findParrot = do
    rv <- findExecutable' "parrot"
    case rv of
        Nothing     -> fail "Cannot find the parrot executable in PATH"
        Just cmd    -> return cmd

evalParrotFile :: FilePath -> IO ()
evalParrotFile file = do
    cmd <- findParrot
    -- parrot -j is fatal on systems where jit is not supported,
    -- so we use the next fastest CGP core.
    args <- getEnv "PUGS_PARROT_OPTS"
    let args' | isJust args && fromJust args /= "" = fromJust args
              | otherwise                          = "-f"
    rawSystem cmd [args', file]
    return ()

evalParrot :: String -> IO ()
evalParrot str = do
    tmp         <- getTemporaryDirectory
    (file, fh)  <- openTempFile tmp "pugs.pir"
    hPutStr fh str
    hClose fh
    evalParrotFile file
    removeFile file

evalPGE :: FilePath -> String -> String -> [(String, String)] -> IO String
evalPGE path match rule subrules = do
    (inp, out, err, pid) <- initPGE path
    (`mapM` subrules) $ \(name, rule) -> do
        let nameStr = escape name
            ruleStr = escape rule
        hPutStrLn inp $ unwords
            ["add_rule", show (length nameStr), show (length ruleStr)]
        hPutStrLn inp nameStr
        hPutStrLn inp ruleStr
    let matchStr = escape match
        ruleStr  = escape rule
    hPutStrLn inp $ unwords
        ["match", show (length matchStr), show (length ruleStr)]
    hPutStrLn inp $ matchStr
    hPutStrLn inp $ ruleStr
    hFlush inp
    rv <- hGetLine out
    case rv of
        ('O':'K':' ':sizeStr) -> do
            size <- readIO sizeStr
            rv   <- sequence (replicate size (hGetChar out))
            ln   <- hGetLine out
            return $ rv ++ ln
        _ -> do
            errMsg  <- hGetContents err
            rv      <- waitForProcess pid
            writeIORef _ParrotInterp Nothing
            let msg | null errMsg = show rv
                    | otherwise   = errMsg
            fail $ "*** Running external 'parrot' failed:\n" ++ msg
    where
    escape = escape . encodeUTF8
    _escape "" = ""
    _escape ('\\':xs) = "\\\\" ++ _escape xs
    _escape ('\n':xs) = "\\n" ++ _escape xs
    _escape (x:xs) = (x:_escape xs)

initPGE :: FilePath -> IO ParrotInterp
initPGE path = do
    rv <- readIORef _ParrotInterp
    case rv of
        Just interp@(_, _, _, pid) -> do
            gone <- getProcessExitCode pid
            if isNothing gone then return interp else do
            writeIORef _ParrotInterp Nothing
            initPGE path
        Nothing -> do
            cmd <- findParrot
            interp <- runInteractiveProcess cmd ["run_pge.pir"] (Just path) Nothing 
            writeIORef _ParrotInterp (Just interp)
            return interp

type ParrotInterp = (Handle, Handle, Handle, ProcessHandle)

{-# NOINLINE _ParrotInterp #-}
_ParrotInterp :: IORef (Maybe ParrotInterp)
_ParrotInterp = unsafePerformIO $ newIORef Nothing

_DoCompile :: Maybe (IORef (String -> FilePath -> String -> IO String))
_DoCompile = Nothing

#else
{-# OPTIONS_GHC -#include "parrot/embed.h" #-}
{-# OPTIONS_GHC -#include "parrot/extend.h" #-}
{-# INCLUDE "../../pge/parrotembed.c" #-}

#include <parrot/parrot.h>

module Pugs.Embed.Parrot where

import Data.IORef
import Foreign.Ptr
import Foreign.C.Types
import Foreign.C.String
import Foreign.Storable
-- import Foreign.StablePtr
import System.IO.Unsafe
import System.Directory
import Pugs.Internals (_GlobalFinalizer)

type ParrotString               = Ptr ()
type ParrotInterp               = Ptr (Ptr ())
type ParrotPackFile             = Ptr ()
type ParrotPackFileByteCode     = Ptr ()
type ParrotPackFileDirectory    = Ptr ()
type ParrotPMC                  = Ptr ()
type ParrotRunCore              = CInt
type ParrotCompilerFunc         = ParrotInterp -> CString -> IO ParrotPMC

{-# NOINLINE _ParrotInterp #-}
_ParrotInterp :: IORef ParrotInterp
_ParrotInterp = unsafePerformIO $ newIORef nullPtr

{-# NOINLINE _DoCompile #-}
_DoCompile :: Maybe (IORef (String -> FilePath -> String -> IO String))
_DoCompile = Just $ unsafePerformIO $ newIORef (error "unregistered")

initParrot :: IO ParrotInterp
initParrot = do
    interp <- readIORef _ParrotInterp 
    if interp /= nullPtr then return interp else do
    parrot_set_config_hash
    interp <- parrot_new nullPtr
    writeIORef _ParrotInterp interp
#if XXX_ENABLE_PARROT_JIT && PARROT_JIT_CAPABLE && defined(PARROT_JIT_CORE)
    parrot_set_run_core interp PARROT_JIT_CORE
#elsif defined(PARROT_FAST_CORE)
    parrot_set_run_core interp PARROT_FAST_CORE
#elsif defined(PARROT_CGP_CORE)
    parrot_set_run_core interp PARROT_CGP_CORE
#elsif defined(PARROT_CGOTO_CORE)
    parrot_set_run_core interp PARROT_CGOTO_CORE
#endif
    -- parrot_set_debug interp 0x20
    -- ptr <- newStablePtr _ParrotInterp
    -- parrot_init_stacktop interp (castStablePtrToPtr ptr)
    parrot_init interp
    parrot_imcc_init interp

{-
    parrot_block_DOD interp
    parrot_block_GC interp
-}

    pf      <- parrot_packfile_new interp 0
    parrot_loadbc interp pf
    seg     <- withCString "pugs" $ \p -> do
        parrot_pf_create_default_segs interp p 1
    set_pf_cur_cs pf seg
    parrot_loadbc interp pf

    callback    <- mkCompileCallback compileToParrot
    pugsStr     <- "Pugs" `makeAscii` interp
    parrot_compreg interp pugsStr callback

    modifyIORef _GlobalFinalizer (>> parrotFinalize)
    -- modifyIORef _GlobalFinalizer (>> parrot_exit 0)

    return interp
    where
    parrotFinalize = do
        interp <- readIORef _ParrotInterp
        if interp == nullPtr then return () else do
        writeIORef _ParrotInterp nullPtr
        parrot_exit interp 0

makeAscii :: String -> ParrotInterp -> IO ParrotString
makeAscii str interp = withCString str (const_string interp)

makeUTF8 :: String -> ParrotInterp -> IO ParrotString
makeUTF8 str interp = withCStringLen str $ \(cstr, len) -> do
    string_make interp cstr len unicodeCStr 0

{-# NOINLINE unicodeCStr #-}
unicodeCStr :: CString
unicodeCStr = unsafePerformIO (newCString "unicode")

loadPGE :: ParrotInterp -> FilePath -> IO (ParrotPMC, ParrotPMC)
loadPGE interp path = do
    ns      <- "PGE::Hs"    `makeAscii` interp
    sym     <- "match"      `makeAscii` interp
    match   <- parrot_find_global interp ns sym
    sym     <- "add_rule"   `makeAscii` interp
    add     <- parrot_find_global interp ns sym
    if match /= nullPtr then return (match, add) else do
    cwd     <- getCurrentDirectory
    setCurrentDirectory path
    pge_pbc <- "PGE.pbc"    `makeAscii` interp
    pge_hs  <- "PGE/Hs.pir" `makeAscii` interp
    parrot_load_bytecode interp pge_pbc
    parrot_load_bytecode interp pge_hs
    setCurrentDirectory cwd
    loadPGE interp path

evalPGE :: FilePath -> String -> String -> [(String, String)] -> IO String
evalPGE path str pat subrules = do
    interp          <- initParrot
    (match, add)    <- loadPGE interp path
    -- set error handler here
    (`mapM_` subrules) $ \(name, rule) -> do
        s1  <- name `makeUTF8` interp
        s2  <- rule `makeUTF8` interp
        callSubSSS interp add s1 s2
    s1  <- str `makeUTF8` interp
    s2  <- pat `makeUTF8` interp
    s5  <- callSubSSS interp match s1 s2
    if s5 == nullPtr
        then do
            parrot_init interp
            parrot_imcc_init interp
            fail "*** Running embedded 'parrot' failed"
        else peekCString =<< parrot_string_to_cstring interp s5

evalParrotFile :: FilePath -> IO ()
evalParrotFile file = do
    interp  <- initParrot
    pf      <- withCString file $ parrot_readbc interp
    parrot_loadbc interp pf
    parrot_runcode interp 0 nullPtr

evalParrot :: String -> IO ()
evalParrot code = do
    interp  <- initParrot
    sub     <- withCString code $ \p -> do
        parrot_imcc_compile_pir interp p
    withCString "vv" $ parrot_call_sub_vv interp sub

compileToParrot :: ParrotInterp -> CString -> IO ParrotPMC
compileToParrot interp cstr = do
    doCompile   <- case _DoCompile of
        Just ioRef  -> readIORef ioRef
        Nothing     -> error "unregistered?"
    code        <- doCompile "Parrot" "-" =<< peekCString cstr
    withCString code $ \p -> do
        parrot_imcc_compile_pir interp p

foreign import ccall "wrapper"  
    mkCompileCallback :: ParrotCompilerFunc -> IO (FunPtr ParrotCompilerFunc)

foreign import ccall "Parrot_set_config_hash"
    parrot_set_config_hash :: IO ()

foreign import ccall "Parrot_new"
    parrot_new :: ParrotInterp -> IO ParrotInterp

foreign import ccall "Parrot_init"
    parrot_init :: ParrotInterp -> IO ()

foreign import ccall "Parrot_init_stacktop"
    parrot_init_stacktop :: ParrotInterp -> Ptr () -> IO ()

foreign import ccall "Parrot_readbc"
    parrot_readbc :: ParrotInterp -> CString -> IO ParrotPackFile

foreign import ccall "Parrot_loadbc"
    parrot_loadbc :: ParrotInterp -> ParrotPackFile -> IO ()

foreign import ccall "Parrot_runcode"
    parrot_runcode :: ParrotInterp -> CInt -> Ptr CString -> IO ()

foreign import ccall "Parrot_destroy"
    parrot_destroy :: ParrotInterp -> IO ()

foreign import ccall "PackFile_new"
    parrot_packfile_new :: ParrotInterp -> CInt -> IO ParrotPackFile

foreign import ccall "PackFile_Segment_new_seg"
    parrot_packfile_segment_new_seg :: ParrotInterp -> ParrotPackFileDirectory -> CInt -> CString-> CInt -> IO ParrotPackFileByteCode

foreign import ccall "PF_create_default_segs"
    parrot_pf_create_default_segs :: ParrotInterp -> CString -> CInt -> IO ParrotPackFileByteCode

foreign import ccall "dod_register_pmc"
    parrot_dod_register_pmc :: ParrotInterp -> ParrotPMC -> IO ()

foreign import ccall "Parrot_set_run_core"
    parrot_set_run_core :: ParrotInterp -> ParrotRunCore -> IO ()

foreign import ccall "Parrot_compreg"
    parrot_compreg :: ParrotInterp -> ParrotString -> FunPtr ParrotCompilerFunc -> IO ()

foreign import ccall "Parrot_load_bytecode"
    parrot_load_bytecode :: ParrotInterp -> ParrotString -> IO ()

foreign import ccall "Parrot_call_sub"
    parrot_call_sub_vv :: ParrotInterp -> ParrotPMC -> CString -> IO ()

foreign import ccall "Parrot_call_sub"
    parrot_call_sub_SSS :: ParrotInterp -> ParrotPMC -> CString -> ParrotString -> ParrotString -> IO ParrotString

foreign import ccall "const_string"
    const_string :: ParrotInterp -> CString -> IO ParrotString

foreign import ccall "string_make"
    string_make :: ParrotInterp -> CString -> Int -> CString -> CInt -> IO ParrotString

foreign import ccall "Pugs_get_base_global"
    parrot_find_global :: ParrotInterp -> ParrotString -> ParrotString -> IO ParrotPMC

foreign import ccall "Parrot_get_strreg"
    parrot_get_strreg :: ParrotInterp -> CInt -> IO ParrotString

foreign import ccall "Parrot_set_debug"
    parrot_set_debug :: ParrotInterp -> CInt -> IO ()

foreign import ccall "Parrot_exit"
    parrot_exit :: ParrotInterp -> CInt -> IO ()

foreign import ccall "string_to_cstring"
    parrot_string_to_cstring :: ParrotInterp -> ParrotString -> IO CString

{-
foreign import ccall "Parrot_block_DOD"
    parrot_block_DOD :: ParrotInterp -> IO ()

foreign import ccall "Parrot_block_GC"
    parrot_block_GC :: ParrotInterp -> IO ()
-}

foreign import ccall "imcc_init"
    parrot_imcc_init :: ParrotInterp -> IO ()

foreign import ccall "imcc_compile_pir"
    parrot_imcc_compile_pir :: ParrotInterp -> CString -> IO ParrotPMC

#def void* Pugs_callSubSSS(void *i, void *p, void *x, void *y)

foreign import ccall "Pugs_callSubSSS"
    callSubSSS :: ParrotInterp -> ParrotPMC -> ParrotString -> ParrotString -> IO ParrotString

#def void imcc_init(Parrot_Interp interpreter)
#def PMC * imcc_compile_pir(Parrot_Interp interp, const char *s)

get_pf_directory :: ParrotPackFile -> IO ParrotPackFileByteCode
get_pf_directory = #peek struct PackFile, directory

set_pf_cur_cs :: ParrotPackFile -> ParrotPackFileByteCode -> IO ()
set_pf_cur_cs = #poke struct PackFile, cur_cs

#endif
