{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Products.DomainTermsAPI
( DomainTermsAPI
, CreateDomainTermsAPI
, RemoveDomainTermAPI
, createDomainTerm
, removeDomainTerm
, productsDomainTerms
) where

import App
import AppConfig (getDBConfig)
import Control.Monad.Reader
import Data.Aeson
import Data.Int (Int64)
import qualified Data.Text              as T
import qualified DomainTerms.DomainTerm as DT
import Models
import qualified Products.Product as P
import Servant
import qualified Servant.Docs     as SD

type DomainTermsAPI       = "domain-terms" :> Get '[JSON] [APIDomainTerm]
type CreateDomainTermsAPI = "domain-terms" :> ReqBody '[JSON] APIDomainTerm :> Post '[JSON] APIDomainTerm
type RemoveDomainTermAPI  = "domain-terms" :> Capture "id" Int :> Delete '[JSON] ()

data APIDomainTerm = APIDomainTerm { domainTermID :: Maybe Int64
                                   , productID    :: Maybe ProductId
                                   , title        :: T.Text
                                   , description  :: T.Text
                                   } deriving (Show)

instance ToJSON APIDomainTerm where
  toJSON (APIDomainTerm termID prodID termTitle termDescription) =
    object [ "id"          .= termID
           , "productID"   .= prodID
           , "title"       .= termTitle
           , "description" .= termDescription
           ]

instance FromJSON APIDomainTerm where
  parseJSON (Object v) = APIDomainTerm <$>
                        v .:? "id" <*>
                        v .:? "productID" <*>
                        v .: "title" <*>
                        v .: "description"
  parseJSON _          = mzero

createDomainTerm :: P.ProductID -> APIDomainTerm -> App APIDomainTerm
createDomainTerm pID (APIDomainTerm _ _ t d) = do
  dbConfig <- reader getDBConfig
  termID   <- liftIO $ DT.createDomainTerm dbConfig (DT.DomainTerm (toKey pID) t d)
  return $ APIDomainTerm { domainTermID = Just termID
                         , productID    = Just (toKey pID)
                         , title        = t
                         , description  = d
                         }

removeDomainTerm :: P.ProductID -> Int -> App ()
removeDomainTerm pID dtID = do
  dbConfig <- reader getDBConfig
  liftIO $ DT.removeDomainTerm dbConfig (toKey pID) (toKey dtID)

productsDomainTerms :: P.ProductID -> App [APIDomainTerm]
productsDomainTerms prodID = do
  dbConfig    <- reader getDBConfig
  domainTerms <- liftIO $ DT.findByProductId dbConfig (toKey prodID)
  return $ map toDomainTerm domainTerms
    where
      toDomainTerm dbDomainTerm = do
        let dbTerm   = DT.toDomainTerm dbDomainTerm
        let dbTermID = DT.toDomainTermID dbDomainTerm
        APIDomainTerm { domainTermID = Just dbTermID
                      , productID    = Just $ domainTermProductId dbTerm
                      , title        = domainTermTitle dbTerm
                      , description  = domainTermDescription dbTerm
                      }

-- API Documentation Instance Definitions --

instance SD.ToSample [APIDomainTerm] [APIDomainTerm] where
  toSample _ = Just $ [ sampleAPIDomainTerm, sampleAPIDomainTerm2 ]

instance SD.ToSample APIDomainTerm APIDomainTerm where
  toSample _ = Just $ samplePostBody

instance SD.ToSample () () where
  toSample _ = Just () 

instance SD.ToCapture (Capture "id" Int) where
  toCapture _ = SD.DocCapture "id" "DomainTerm id"

sampleAPIDomainTerm :: APIDomainTerm
sampleAPIDomainTerm = APIDomainTerm (Just 1) (Just (toKey (10::Integer))) "mutation" "The genetic alteration granting monster powers"

sampleAPIDomainTerm2 :: APIDomainTerm
sampleAPIDomainTerm2 = APIDomainTerm (Just 2) (Just (toKey (10::Integer))) "vampirism" "The disease affecting Vampires"

samplePostBody :: APIDomainTerm
samplePostBody = APIDomainTerm (Just 2) (Just (toKey (10::Integer))) "monsterism" "The quality of being a monster"
