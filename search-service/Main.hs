module Main where

import Control.Monad.Except (runExceptT)
import Data.Text (pack)
import Data.Traversable (sequence)
import Features.Feature as F
import qualified Features.SearchableFeature as SF
import System.Environment (getEnv)

data AppConfig =
  AppConfig { elasticSearchUrl :: String
            , featureFilePath  :: String
            }

newtype CReader a = CReader { runConfigReader :: AppConfig -> a }

instance Functor CReader where
  fmap f cr = CReader $ \c -> f (runConfigReader cr c)

instance Applicative CReader where
  pure = return
  (CReader f) <*> (CReader a) = CReader $ \c -> (f c) (a c)

instance Monad CReader where
  return  = CReader . const
  a >>= f = CReader $ \c -> let a' = runConfigReader a c
                                f' = f a'
                            in runConfigReader f' c
  {- this is equivalent, but harder to read -}
  {- a >>= f = CReader $ \c -> runConfigReader (f ((runConfigReader a) c)) c -}

main :: IO ()
main = do
  appConfig <- readConfig
  runConfigReader indexFeaturesCR appConfig

readConfig :: IO AppConfig
readConfig = do
  esUrl         <- getEnv "FC_ELASTIC_SEARCH_URL"
  dataFilesPath <- getEnv "FC_DATA_FILES_PATH"
  let baseFilePath = dataFilesPath ++ "/products/39/repo"
  return $ AppConfig esUrl baseFilePath


askConfig :: CReader AppConfig
askConfig = CReader id

indexFeaturesCR :: CReader (IO ())
indexFeaturesCR = fmap indexFeatures askConfig

indexFeatures :: AppConfig -> IO ()
indexFeatures appConfig = do
  featureFiles <- runExceptT $ F.findFeatureFiles (featureFilePath appConfig)
  case featureFiles of
    Left errorStr ->
      putStrLn errorStr

    Right features -> do
      searchableFeatures <- sequence $ buildSearchableFeatures features appConfig
      replies            <- SF.indexFeatures searchableFeatures
      putStrLn $ foldr (\x acc -> acc ++ "\n" ++ (show x)) "" replies

buildSearchableFeatures :: [FilePath] -> AppConfig -> [IO SF.SearchableFeature]
buildSearchableFeatures filePaths appConfig =
  let fileDetails = map ((flip getFileConetnts) appConfig) filePaths
  in
    map (fmap buildSearchableFeature) fileDetails

getFileConetnts :: FilePath -> AppConfig -> IO (FilePath, String)
getFileConetnts filePath appConfig = do
  let fullFilePath = (featureFilePath appConfig) ++ filePath
  fileContents <- readFile fullFilePath
  return (filePath, fileContents)

buildSearchableFeature :: (FilePath, String) -> SF.SearchableFeature
buildSearchableFeature (filePath, fileContents) =
  SF.SearchableFeature { SF.featurePath = pack filePath
                       , SF.featureText = pack fileContents
                       }
