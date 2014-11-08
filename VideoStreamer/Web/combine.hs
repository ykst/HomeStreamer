module Main where
import System.Environment (getArgs)
import Text.Parsec
import Text.Parsec.String
import Control.Monad.Trans (liftIO)
import Control.Applicative hiding ((<|>), many, optional)

annotateP :: ParsecT String () IO String
annotateP = (try (wrapP ((try logP) <|> (try includeP) <|> (try debugP) <|> (try throwP)))) <|> (many anyChar)
    where 
    wrapP innerP = (++) <$> many (satisfy ('@' /=)) <*> ((++) <$> innerP <*> many anyChar)
    pragmaP :: String -> (String -> ParsecT String () IO String) -> ParsecT String () IO String
    pragmaP name action = (string ("@" ++ name) <* spaces) >> 
               (between (char '(' <* spaces) (char ')') (many (noneOf ")") <* spaces)) >>= action
    includeP = pragmaP "include" (liftIO . fromFile)
    logP = pragmaP "log" (\s -> (pure ("/*" ++ s ++ "*/")))
    debugP = pragmaP "debug" (const (pure ""))
    throwP = pragmaP "throw" (\s -> (pure ("throw '';/*" ++ s ++ "*/")))

fromFile path = readFile path >>= convert "" . lines
    where
    convert accum [] = pure accum
    convert accum (l:ls) = 
        runParserT annotateP () "" l >>=
        (\str -> convert (accum ++ "\n" ++ str) ls) . either (error . show) (id)

main = getArgs >>= \args -> case args of
    [path] -> fromFile path >>= putStrLn
    _ -> putStrLn "specify one file"
