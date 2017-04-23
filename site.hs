--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import qualified Debug.Trace as DT
import           Hakyll
import           Data.Monoid ((<>))


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
  match "images/*" $ do
    route   idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route   idRoute
    compile compressCssCompiler

  match "posts/*" $ do
    route $ setExtension "html"
    compile $ pandocCompiler
      >>= saveSnapshot "rawContent"
      >>= loadAndApplyTemplate "templates/post.html" blogCtx
      >>= saveSnapshot "content"
      >>= loadAndApplyTemplate "templates/default.html" blogCtx
      >>= relativizeUrls

  match "pages/*" $ do
    route $ setExtension "html"
    compile $ do
      posts <- recentFirst =<< loadAll "posts/*"
      let teaserCtx = teaserField "teaser" "rawContent" `mappend` blogCtx
      let pagesCtx =
            listField "posts" teaserCtx (return posts) `mappend`
            blogCtx

      getResourceBody
        >>= applyAsTemplate pagesCtx
        >>= loadAndApplyTemplate "templates/default.html" blogCtx
        >>= relativizeUrls

  match "index.html" $ do
    route idRoute
    compile $ do
      let indexCtx =
            constField "title" "Home"                `mappend`
            blogCtx

      getResourceBody
        >>= applyAsTemplate indexCtx
        >>= loadAndApplyTemplate "templates/default.html" blogCtx
        >>= relativizeUrls

  match "templates/*" $ compile templateBodyCompiler

  create ["atom.xml"] $ do
    route idRoute
    compile $ do
        let feedCtx = blogCtx `mappend` bodyField "description"
        posts <- fmap (take 10) . recentFirst =<<
          loadAllSnapshots "posts/*" "content"
        renderAtom myFeedConfiguration feedCtx posts


--------------------------------------------------------------------------------

isPage :: String -> Item String -> Bool
isPage pageName item = pageName == (toFilePath $ itemIdentifier item)

blogCtx :: Context String
blogCtx =
  boolField "isRoot" (isPage "index.html") `mappend`
  boolField "isPosts" (isPage "pages/posts.html") `mappend`
  constField "currentYear" "2017" `mappend`
  dateField "date" "%B %e, %Y" `mappend`
  defaultContext

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "MonadCat: Latest posts"
    , feedDescription = "Words about Haskell, Maths, JS and life"
    , feedAuthorName  = "Michal Kawalec"
    , feedAuthorEmail = "michal@monad.cat"
    , feedRoot        = "https://monad.cat"
    }
