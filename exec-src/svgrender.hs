import Control.Applicative( (<$>) )
import Control.Monad( forM_ )
import Data.Binary( encodeFile, decodeOrFail  )
import qualified Data.ByteString.Lazy as B
import Data.List( isSuffixOf, sort )
import System.Environment( getArgs )
import System.Directory( createDirectoryIfMissing
                       , getDirectoryContents
                       , doesFileExist
                       )
import System.FilePath( dropExtension, (</>), (<.>), splitFileName )

import Codec.Picture( writePng )

import Graphics.Text.TrueType( FontCache, buildCache )
import Graphics.Rasterific.Svg
import Graphics.Svg
{-import Debug.Trace-}
import Text.Printf

loadCreateFontCache :: IO FontCache
loadCreateFontCache = do
  exist <- doesFileExist filename
  if exist then loadCache else createWrite
  where
    filename =  "fonty-texture-cache"
    loadCache = do
      putStrLn "Loading pre-existing font cache"
      bstr <- B.readFile filename
      case decodeOrFail bstr of
        Left _ -> do
          putStrLn "Failed to load cache, recreate"
          createWrite
        Right (_, _, v) -> do
          putStrLn "Done"
          return v
      
    createWrite = do
      putStrLn "Building font cache..."
      cache <- buildCache
      putStrLn "Saving font cache..."
      encodeFile filename cache
      putStrLn "Done"
      return cache

loadRender :: [String] -> IO ()
loadRender [] = putStrLn "not enough arguments"
loadRender [_] = putStrLn "not enough arguments"
loadRender (svgfilename:pngfilename:_) = do
  f <- loadSvgFile svgfilename
  case f of
     Nothing -> putStrLn "Error while loading SVG"
     Just doc -> do
        cache <- loadCreateFontCache
        (finalImage, _) <- renderSvgDocument cache Nothing doc
        writePng pngfilename finalImage

type Html = String

testOutputFolder :: FilePath
testOutputFolder = "gen_test"

img :: FilePath -> Int -> Int -> Html
img path _w _h =
    printf "<img src=\"%s\" alt=\"%s\" />" path path

table :: [Html] -> [[Html]] -> Html
table headers cells =
        "<table>" ++ header ++ concat ["<tr>" ++ elems row ++ "</tr>\n" | row <- cells ] ++ "</table>"
  where elems row = concat ["<td>" ++ cell ++ "</td>\n" | cell <- row  ]
        header = "<tr>" ++ concat ["<th>" ++ h ++ "</th>" | h <- headers ] ++ "</tr>"

testFileOfPath :: FilePath -> FilePath
testFileOfPath path = testOutputFolder </> base <.> "png"
  where (_, base) = splitFileName path

svgTestFileOfPath :: FilePath -> FilePath
svgTestFileOfPath path = testOutputFolder </> base <.> "svg"
  where (_, base) = splitFileName path


text :: String -> Html
text txt = txt ++ "<br/>"

generateFileInfo :: FilePath -> [Html]
generateFileInfo path =
    [ text path, img path 0 0
    , img pngRef 0 0
    , img (testFileOfPath path) 0 0
    , img (svgTestFileOfPath path) 0 0]
  where
    pngRef = dropExtension path <.> "png"

toHtmlDocument :: Html -> String
toHtmlDocument html =
    "<html><head><title>Test results</title></head><body>" ++ html ++ "</body></html"

analyzeFolder :: FontCache -> FilePath -> IO ()
analyzeFolder cache folder = do
  createDirectoryIfMissing True testOutputFolder
  fileList <- sort . filter (".svg" `isSuffixOf`) <$> getDirectoryContents folder
  let all_table = table ["name", "W3C Svg", "W3C ref PNG", "mine", "svgmine"]
                . map generateFileInfo $ map (folder </>) fileList
      doc = toHtmlDocument all_table
      (_, folderBase) = splitFileName folder

  print fileList

  writeFile (folder </> ".." </> folderBase <.> "html") doc
  forM_ fileList $ \p -> do
    let realFilename = folder </> p
    putStrLn $ "Loading: " ++ realFilename
    svg <- loadSvgFile realFilename
    {-print svg-}
    case svg of
      Nothing -> putStrLn $ "Failed to load " ++ p
      Just d -> do
        putStrLn $ "   => Rendering " ++ show (documentSize d)
        (finalImage, _) <- renderSvgDocument cache Nothing d
        writePng (testFileOfPath p) finalImage

        putStrLn "   => XMLize"
        saveXmlFile (svgTestFileOfPath p) d


testSuite :: IO ()
testSuite = do
    cache <- loadCreateFontCache
    analyzeFolder cache "w3csvg"
    analyzeFolder cache "test"

main :: IO ()
main = do
    args <- getArgs
    case args of
      "test":_ -> testSuite
      _ -> loadRender args

