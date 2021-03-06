module Layouts.Default
  ( withDefaultLayout
  ) where

import Text.Blaze.Html5 (Html, (!))
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

withDefaultLayout :: Html -> Html
withDefaultLayout content = H.docTypeHtml $ do
  header
  body content

header :: Html
header =
  H.head $ do
    bootstrapCSS
    jQuery
    bootstrapJS
    appJS
    meta
    H.title "Feature Creature"

meta :: Html
meta =
  H.meta
    ! A.name "viewport"
    ! A.content "width=device-width, initial-scale=1"

bootstrapCSS :: Html
bootstrapCSS = do
  H.link
    ! A.rel "stylesheet"
    ! A.href "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css"
  H.link
    ! A.rel "stylesheet"
    ! A.href "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css"

bootstrapJS :: Html
bootstrapJS =
  H.script
    ! A.src "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"
    $ ""

appJS :: Html
appJS = do
  H.script
    ! A.src "public/elm.js"
    $ ""
  H.script
    ! A.src "public/init.js"
    $ ""

body :: Html -> Html
body content =
  H.body $ do
    H.div ! A.class_ "container" $ do
      content

jQuery :: Html
jQuery =
  H.script
    ! A.src "https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"
    $ ""
