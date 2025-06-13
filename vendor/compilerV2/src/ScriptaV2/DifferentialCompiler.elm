module ScriptaV2.DifferentialCompiler exposing (EditRecord, init, update, renderEditRecord, messagesFromForest, editRecordToCompilerOutput)

{-|

@docs EditRecord, init, update, renderEditRecord, messagesFromForest, editRecordToCompilerOutput

-}

import Dict exposing (Dict)
import Differential.AbstractDifferentialParser
import Differential.Differ
import Differential.Utility
import Either exposing (Either)
import Element exposing (Element)
import Element.Font as Font
import Generic.ASTTools
import Generic.Acc
import Generic.BlockUtilities
import Generic.Compiler
import Generic.Forest exposing (Forest)
import Generic.ForestTransform
import Generic.Language exposing (ExpressionBlock, PrimitiveBlock)
import Generic.Pipeline
import Generic.PrimitiveBlock
import Library.Tree
import M.Expression
import M.PrimitiveBlock
import MicroLaTeX.Expression
import MicroLaTeX.PrimitiveBlock
import Render.Block
import Render.TOCTree
import RoseTree.Tree as Tree exposing (Tree)
import ScriptaV2.Compiler
import ScriptaV2.Config
import ScriptaV2.Language exposing (Language(..))
import ScriptaV2.Msg exposing (MarkupMsg)
import ScriptaV2.Settings
import XMarkdown.Expression
import XMarkdown.PrimitiveBlock


{-| -}
renderEditRecord : Generic.Compiler.DisplaySettings -> EditRecord -> List (Element MarkupMsg)
renderEditRecord displaySettings editRecord =
    let
        renderSettings =
            ScriptaV2.Settings.renderSettingsFromDisplaySettings displaySettings

        counter =
            displaySettings.counter
    in
    ScriptaV2.Compiler.renderForest counter renderSettings editRecord.accumulator editRecord.tree


{-| -}
editRecordToCompilerOutput : ScriptaV2.Compiler.Filter -> Generic.Compiler.DisplaySettings -> EditRecord -> ScriptaV2.Compiler.CompilerOutput
editRecordToCompilerOutput filter displaySettings editRecord =
    let
        renderSettings : ScriptaV2.Settings.RenderSettings
        renderSettings =
            ScriptaV2.Settings.renderSettingsFromDisplaySettings displaySettings

        viewParameters =
            { idsOfOpenNodes = displaySettings.idsOfOpenNodes
            , selectedId = displaySettings.selectedId
            , counter = displaySettings.counter
            , attr = []
            , settings = renderSettings
            }

        toc : List (Element MarkupMsg)
        toc =
            Render.TOCTree.view viewParameters editRecord.accumulator editRecord.tree

        banner : Maybe (Element MarkupMsg)
        banner =
            Generic.ASTTools.banner editRecord.tree
                |> Maybe.map (Render.Block.renderBody displaySettings.counter editRecord.accumulator renderSettings [ Font.color (Element.rgb 1 0 0) ])
                |> Maybe.map (Element.row [ Element.height (Element.px 40) ])

        title : Element MarkupMsg
        title =
            Element.paragraph [] [ Element.text <| Generic.ASTTools.title editRecord.tree ]
    in
    { body =
        ScriptaV2.Compiler.renderForest displaySettings.counter renderSettings editRecord.accumulator (ScriptaV2.Compiler.filterForest2 editRecord.tree)
    , banner = banner
    , toc = toc -- THIS IS WHERE THE SIDEBAR TOC IS COMPUTED
    , title = title
    }


{-| -}
type alias EditRecord =
    Differential.AbstractDifferentialParser.EditRecord PrimitiveBlock ExpressionBlock Generic.Acc.Accumulator


type alias ExpBlockData =
    { name : Maybe String, args : List String, properties : Dict String String, indent : Int, lineNumber : Int, numberOfLines : Int, id : String, tag : String, content : Either String (List Generic.Language.Expression), messages : List String, sourceText : String }


{-| -}
init : Dict String String -> Language -> String -> EditRecord
init inclusionData lang str =
    let
        initialData : { language : Language, mathMacros : String, textMacros : String, vectorSize : number }
        initialData =
            makeInitialData inclusionData lang
    in
    Differential.AbstractDifferentialParser.init (updateFunctions lang) initialData (str ++ "\n")


default lang =
    { mathMacros = ""
    , textMacros = ""
    , vectorSize = 4
    , language = lang
    }


makeInitialData : Dict String String -> Language -> { language : Language, mathMacros : String, textMacros : String, vectorSize : number }
makeInitialData filesToIncludeDict lang =
    let
        keys =
            Dict.keys filesToIncludeDict

        macroKeys =
            List.filter (\k -> String.contains "texmacros" (String.toLower k)) keys

        getMacroText key =
            case Dict.get key filesToIncludeDict of
                Nothing ->
                    Nothing

                Just macroText_ ->
                    Just
                        { mathmacros = Differential.Utility.getKeyedParagraph "|| mathmacros" macroText_ |> Maybe.withDefault ""
                        , textmacros = Differential.Utility.getKeyedParagraph "|| textmacros" macroText_ |> Maybe.withDefault ""
                        }

        -- foldl : (a -> b -> b) -> b -> List a -> b
        folder new acc =
            { mathmacros = new.mathmacros ++ "\n" ++ acc.mathmacros, textmacros = new.textmacros ++ "\n" ++ acc.textmacros }

        macroTexts : { mathmacros : String, textmacros : String }
        macroTexts =
            List.map getMacroText keys
                |> List.filterMap identity
                |> List.foldl folder { mathmacros = "", textmacros = "" }
                |> (\r -> { mathmacros = fixup "|| mathmacros" r.mathmacros, textmacros = fixup "|| textmacros" r.textmacros })

        fixup key str =
            str
                |> String.lines
                |> List.map (\str_ -> String.replace key "" str_ |> String.trim)
                |> List.filter (\str_ -> String.length str_ > 0)
                |> String.join "\n"
                |> (\x -> key ++ "\n" ++ x)
    in
    { language = lang
    , mathMacros = macroTexts.mathmacros
    , textMacros = macroTexts.textmacros
    , vectorSize = 4
    }


updateFunctions : Language -> Differential.AbstractDifferentialParser.UpdateFunctions PrimitiveBlock ExpressionBlock Generic.Acc.Accumulator
updateFunctions lang =
    { chunker = chunker lang -- String -> List PrimitiveBlock
    , chunkEq = Generic.PrimitiveBlock.eq -- PrimitiveBlock -> PrimitiveBlock -> Bool
    , lineNumber = pGetLineNumber -- PrimitiveBlock -> Maybe Int
    , pLineNumber = eGetLineNumber
    , changeLineNumber = changeLineNumber
    , setLineNumber = Generic.BlockUtilities.setLineNumber
    , chunkLevel = chunkLevel -- PrimitiveBlock -> Bool
    , diffPostProcess = identity
    , chunkParser = toExprBlock lang --  PrimitiveBlock -> parsedChunk
    , forestFromBlocks = Generic.ForestTransform.forestFromBlocks .indent -- : List parsedChunk -> List (Tree parsedChunk)
    , getMessages = messagesFromForest -- : List parsedChunk -> List String
    , accMaker = Generic.Acc.transformAccumulate -- : Scripta.Language.Language -> Forest parsedChunk -> (acc, Forest parsedChunk)
    }


pGetLineNumber : PrimitiveBlock -> Int
pGetLineNumber block =
    block.meta.lineNumber


eGetLineNumber : ExpressionBlock -> Int
eGetLineNumber block =
    block.meta.lineNumber


{-| -}
messagesFromForest : Forest ExpressionBlock -> List String
messagesFromForest forest =
    List.map messagesFromTree forest |> List.concat


messagesFromTree : Tree.Tree ExpressionBlock -> List String
messagesFromTree tree =
    List.map Generic.BlockUtilities.getMessages (Library.Tree.flatten tree) |> List.concat


changeLineNumber : Int -> ExpressionBlock -> ExpressionBlock
changeLineNumber delta block =
    let
        oldMeta =
            block.meta

        newMeta =
            { oldMeta | lineNumber = oldMeta.lineNumber + delta }
    in
    { block | meta = newMeta }



-- Parser.Block.setLineNumber (lineNumber + delta) block


diffPostProcess : Differential.Differ.DiffRecord PrimitiveBlock -> Differential.Differ.DiffRecord PrimitiveBlock
diffPostProcess diffRecord =
    let
        lengthS =
            Generic.PrimitiveBlock.listLength diffRecord.middleSegmentInSource

        lengthT =
            Generic.PrimitiveBlock.listLength diffRecord.middleSegmentInTarget

        delta =
            lengthT - lengthS
    in
    shiftLines delta diffRecord


shiftLines : Int -> Differential.Differ.DiffRecord PrimitiveBlock -> Differential.Differ.DiffRecord PrimitiveBlock
shiftLines delta diffRecord =
    { diffRecord | commonSuffix = shiftLinesInBlockList delta diffRecord.commonSuffix }


shiftLinesInBlock : Int -> PrimitiveBlock -> PrimitiveBlock
shiftLinesInBlock delta block =
    let
        oldMeta =
            block.meta

        newMeta =
            { oldMeta | lineNumber = oldMeta.lineNumber + delta }
    in
    { block | meta = newMeta }


shiftLinesInBlockList : Int -> List PrimitiveBlock -> List PrimitiveBlock
shiftLinesInBlockList delta blockList =
    List.map (shiftLinesInBlock delta) blockList


chunkLevel : PrimitiveBlock -> Int
chunkLevel block =
    block.indent
        + (if Generic.BlockUtilities.getPrimitiveBlockName block == Just "item" || Generic.BlockUtilities.getPrimitiveBlockName block == Just "numbered" then
            1

           else
            0
          )


getMessages_ : List ExpressionBlock -> List String
getMessages_ blocks =
    List.map Generic.BlockUtilities.getMessages blocks |> List.concat


{-| -}
update : EditRecord -> String -> EditRecord
update editRecord text =
    Differential.AbstractDifferentialParser.update (updateFunctions editRecord.lang) (text ++ "\n") editRecord


chunker : Language -> String -> List PrimitiveBlock
chunker lang str =
    case lang of
        MicroLaTeXLang ->
            MicroLaTeX.PrimitiveBlock.parse ScriptaV2.Config.idPrefix 0 (String.lines str)

        EnclosureLang ->
            M.PrimitiveBlock.parse ScriptaV2.Config.idPrefix 0 (String.lines str)

        SMarkdownLang ->
            XMarkdown.PrimitiveBlock.parse ScriptaV2.Config.idPrefix 0 (String.lines str)


toExprBlock : Language -> PrimitiveBlock -> ExpressionBlock
toExprBlock lang =
    case lang of
        MicroLaTeXLang ->
            Generic.Pipeline.toExpressionBlock MicroLaTeXLang MicroLaTeX.Expression.parse

        EnclosureLang ->
            Generic.Pipeline.toExpressionBlock EnclosureLang M.Expression.parse

        SMarkdownLang ->
            Generic.Pipeline.toExpressionBlock SMarkdownLang XMarkdown.Expression.parse
