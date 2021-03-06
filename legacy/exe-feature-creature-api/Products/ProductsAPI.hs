{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Products.ProductsAPI
( ProductsAPI
, productsAPI
, productsServer
) where

import App
import AppConfig (DBConfig (..), getDBConfig, getRabbitMQConfig)
import Messaging.Job as Job (Job (..), JobType (..))
import Control.Monad.Reader
import Data.Aeson
import Data.Time.Clock as Clock
import Database.Types (runPool)
import qualified Messaging.Products         as MP
import ModelTypes (RepositoryState (..))
import Network.AMQP.MessageBus              as MB
import qualified Products.DomainTermsAPI    as DT
import qualified Products.FeaturesAPI       as F
import qualified Products.Product           as P
import qualified Products.ProductRepo       as PR
import qualified Products.UserRolesAPI      as UR
import Servant

type ProductsAPI = Get '[JSON] [PR.ProductRepo]
              :<|> ProductIDCapture :> Get '[JSON] PR.ProductRepo
              :<|> ReqBody '[JSON] PR.ProductRepo :> Post '[JSON] PR.ProductRepo
              :<|> ProductIDCapture :> F.FeaturesAPI
              :<|> ProductIDCapture :> F.FeatureAPI
              :<|> ProductIDCapture :> DT.DomainTermsAPI
              :<|> ProductIDCapture :> DT.CreateDomainTermsAPI
              :<|> ProductIDCapture :> DT.EditDomainTermsAPI
              :<|> ProductIDCapture :> DT.RemoveDomainTermAPI
              :<|> ProductIDCapture :> UR.UserRolesAPI
              :<|> ProductIDCapture :> UR.CreateUserRolesAPI
              :<|> ProductIDCapture :> UR.EditUserRolesAPI
              :<|> ProductIDCapture :> UR.RemoveUserRoleAPI

type ProductIDCapture = Capture "id" P.ProductID

productsServer :: ServerT ProductsAPI App
productsServer = getProducts
            :<|> getProduct
            :<|> createProduct
            :<|> F.productsFeatures
            :<|> F.productsFeature
            :<|> DT.productsDomainTerms
            :<|> DT.createDomainTerm
            :<|> DT.editDomainTerm
            :<|> DT.removeDomainTerm
            :<|> UR.productsUserRoles
            :<|> UR.createUserRole
            :<|> UR.editUserRole
            :<|> UR.removeUserRole

productsAPI :: Proxy ProductsAPI
productsAPI = Proxy

createProduct :: PR.ProductRepo -> App PR.ProductRepo
createProduct (PR.ProductRepo _ pName pRepoUrl _ _) = ask
  >>= \cfg     -> (liftIO Clock.getCurrentTime)
  >>= \utcTime -> saveNewProduct (P.Product pName pRepoUrl utcTime)
  >>= \prodID  ->
        let prodRepo = (PR.ProductRepo (Just prodID) pName pRepoUrl Unready Nothing)
            job = Job Job.ProductCreated prodRepo
        in (liftIO $ MB.withConn (getRabbitMQConfig cfg) (sendProductCreatedMessage job))
            >> return prodRepo

getProducts :: App [PR.ProductRepo]
getProducts = (getPool <$> reader getDBConfig) >>=
  liftIO . (runReaderT (runPool PR.findProductRepos))

getProduct :: P.ProductID -> App PR.ProductRepo
getProduct prodID = (getPool <$> reader getDBConfig) >>=
  liftIO . (runReaderT (runPool (PR.findProductRepo prodID))) >>= \result ->
    case result of
      Nothing -> lift $ throwError $ err404
      Just prodRepo -> return prodRepo

saveNewProduct :: P.Product -> App P.ProductID
saveNewProduct p = (reader getDBConfig) >>= \cfg ->
  liftIO $ runReaderT (runPool (P.createProductWithRepoStatus p Unready)) (getPool cfg)

sendProductCreatedMessage :: ToJSON a => Job a -> WithConn ()
sendProductCreatedMessage job =
  MP.subscribeToProductCreation -- we may not need to do this here
    >> MB.produceTopicMessage (MP.productCreatedTopic MP.FeatureCreatureAPI) (MB.Message job)
