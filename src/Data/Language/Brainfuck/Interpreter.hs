{-# LANGUAGE DeriveDataTypeable #-}

module Data.Language.Brainfuck.Interpreter
    ( boot
    , run
    , Machine()
    , InterpreterException(..)
    )
where

import Data.Language.Brainfuck.Types

import qualified Data.Vector.Mutable as MV
import Control.Exception (throwIO, Exception)
import Control.Monad (foldM)
import Data.Char (ord, chr)
import Data.Functor ((<$>))
import Data.Typeable (Typeable)

data Machine = Machine Int (MV.IOVector Int)

data InterpreterException
    = AtStartOfMemory
    | AtEndOfMemory
    deriving (Show, Typeable)

instance Exception InterpreterException

boot :: Int -> IO Machine
boot memSize = Machine 0 <$> MV.replicate memSize 0

run :: Machine -> Program -> IO Machine
run = foldM exec

exec :: Machine -> Instruction -> IO Machine
exec m@(Machine idx mem) (AdjustCellPtr v)
    | v > 0 = if idx + v < MV.length mem
                then return (Machine (idx + v) mem)
                else throwIO AtEndOfMemory
    | v < 0 = if idx + v >= 0
                then return (Machine (idx + v) mem)
                else throwIO AtStartOfMemory
    | otherwise = return m
exec m (AdjustCellAt ofs v) = getCellAt ofs m >>= setCellAt ofs m . (+v) >> return m
exec m (SetCellAt ofs v) = setCellAt ofs m v >> return m
exec m PutChar = getCell m >>= putChar . chr >> return m
exec m GetChar = getChar >>= setCell m . ord >> return m
exec m l@(Loop p) = do
    curVal <- getCell m
    if curVal /= 0
        then run m p >>= \m' -> exec m' l
        else return m

getCell :: Machine -> IO Int
getCell = getCellAt 0

getCellAt :: Int -> Machine -> IO Int
getCellAt offset (Machine idx mem) = MV.read mem (idx + offset)

setCell:: Machine -> Int -> IO ()
setCell = setCellAt 0

setCellAt :: Int -> Machine -> Int -> IO ()
setCellAt offset (Machine idx mem) = MV.write mem (idx + offset)
