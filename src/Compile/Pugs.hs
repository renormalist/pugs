{-# OPTIONS -cpp -fglasgow-exts -fth #-}

module Compile.Pugs where
import Internals

genPugs :: (Show a, Monad m) => a -> m String
genPugs exp = return . unlines $
    [ "{-# OPTIONS -fglasgow-exts -fno-warn-unused-imports -fno-warn-unused-binds -O #-}"
    , "module MainCC where"
    , "import Run"
    , "import AST"
    , "import Internals"
    , ""
    , "mainCC = runAST $ " ++ show exp
    ]
