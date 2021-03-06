{-# LANGUAGE TypeFamilies #-}

module Routing
  ( API
  , marketingApi
  , server
  , genAuthServerContext
  ) where


import App (AppT, AppConfig (..))
import Cookies (parseCookies)
import Control.Monad.Except (runExceptT, liftIO)
import Data.ByteString (ByteString)
import qualified Data.Map as Map
import Data.Monoid ((<>))
import Data.Text (Text)
import Errors (AppError (..))
import qualified Errors as E
import qualified Home.Controller as Home
import JWT (JWT)
import qualified JWT
import Network.Wai (Request, requestHeaders)
import qualified Private.Controller as Private
import Servant
import Servant.Server.Experimental.Auth (AuthHandler, AuthServerData, mkAuthHandler)
import Servant.Server.Experimental.Auth()
import Users.Api (User (..))
import qualified Users.Api as Users

type API = MarketingAPI

type MarketingAPI = AuthProtect "auth-token-opt" :> Home.HomeAPI
  :<|> "private" :> AuthProtect "auth-token-req" :> Private.PrivateAPI

type instance AuthServerData (AuthProtect "auth-token-opt") = Maybe User
type instance AuthServerData (AuthProtect "auth-token-req") = User

genAuthServerContext :: AppConfig
                     -> Context '[ AuthHandler Request User
                                 , AuthHandler Request (Maybe User)
                                 ]
genAuthServerContext cfg =
  (authReqHandler cfg)
    :. (authOptHandler cfg)
    :. EmptyContext

server :: ServerT API AppT
server = Home.rootPath
    :<|> Private.showA

marketingApi :: Proxy API
marketingApi = Proxy

authReqHandler :: AppConfig -> AuthHandler Request User
authReqHandler AppConfig{..} =
  let handler req = case lookup "Cookie" (requestHeaders req) of
        Nothing     -> E.raiseAppError AuthenticationRequired
        Just cookie -> do
          liftIO $ putStrLn . show $ "All Cookies: " <> cookie
          mUser <- liftIO $ loadCurrentUser getUsersApiConfig cookie
          case mUser of
            Nothing -> E.raiseAppError AuthenticationRequired
            (Just user) -> return user
  in mkAuthHandler handler

authOptHandler :: AppConfig -> AuthHandler Request (Maybe User)
authOptHandler AppConfig{..} =
  let handler req = case lookup "Cookie" (requestHeaders req) of
        Nothing     -> return Nothing
        Just cookie -> do
          liftIO $ loadCurrentUser getUsersApiConfig cookie
  in mkAuthHandler handler

loadCurrentUser :: Users.Config -> ByteString -> IO (Maybe User)
loadCurrentUser cfg cookie =
  case findAuthToken cookie >>= parseJWT >>= JWT.getSubject of
    Nothing       -> return Nothing
    (Just authId) -> fetchUser cfg authId

findAuthToken :: ByteString -> Maybe Text
findAuthToken c = Map.lookup "auth-token" $ parseCookies c

parseJWT :: Text -> Maybe JWT
parseJWT encJWT = eitherToMaybe $ JWT.decodeJWT encJWT

fetchUser :: Users.Config -> Text -> IO (Maybe User)
fetchUser cfg authId = eitherToMaybe <$> (runExceptT $ Users.findUser authId cfg)

eitherToMaybe :: Either l r -> Maybe r
eitherToMaybe (Left _)  = Nothing
eitherToMaybe (Right r) = Just r
