module Generic.Language exposing
    ( Block
    , BlockMeta
    , Expr(..)
    , ExprMeta
    , Expression
    , ExpressionBlock
    , Heading(..)
    , PrimitiveBlock
    , SimpleExpressionBlock
    , SimplePrimitiveBlock
    , Style
    , StyleAttr(..)
    , StyleColor(..)
    , boostBlock
    , composeTextElement
    , emptyBlockMeta
    , expressionBlockEmpty
    , extractText
    , getExpressionContent
    , getFunctionName
    , getIdFromBlock
    , getMeta
    , getMetaFromBlock
    , getName
    , getNameFromHeading
    , getVerbatimContent
    , prefixIdInBlockMeta
    , primitiveBlockEmpty
    , setName
    , simplifyBlock
    , simplifyExpr
    , simplifyExpressionBlock
    , simplifyForest
    , simplifyPrimitiveBlock
    , simplifyTree
    , updateMeta
    , updateMetaInBlock
    )

import Dict exposing (Dict)
import Either exposing (Either(..))
import RoseTree.Tree as Tree exposing (Tree)



-- PARAMETRIZED TYPES


type Expr metaData
    = Text String metaData
    | Fun String (List (Expr metaData)) metaData
    | VFun String String metaData


extractText : Expr metaData -> Maybe ( String, metaData )
extractText expr =
    case expr of
        Text text meta ->
            Just ( text, meta )

        _ ->
            Nothing


composeTextElement : String -> metaData -> Expr metaData
composeTextElement text meta =
    Text text meta


type ScriptaExpressions metaData
    = List (Tree (Expr metaData))


{-|

    PrimitiveBlocks, content = String
    ExpressionBlocks, content = Eith
    er String (List Expression)

-}
type alias Block content blockMetaData =
    { heading : Heading
    , indent : Int
    , args : List String
    , properties : Dict String String
    , firstLine : String
    , body : content
    , meta : blockMetaData
    , style : Maybe Style
    }


type alias Style =
    { lineWidth : Int
    , lineSpacing : Int
    , spaceAbove : Int
    , spaceBelow : Int
    , indent : Int
    , firstLineIndent : Int
    , fontSize : Int
    , borderWidth : Maybe Int
    , bgColor : StyleColor
    , fgColor : StyleColor
    , borderColor : Maybe StyleColor
    , attrs : List StyleAttr
    }


type StyleColor
    = RGB Float Float Float
    | RGBA Float Float Float Float


type StyleAttr
    = None
    | Italic


defaultStyle : Style
defaultStyle =
    { lineWidth = 600
    , lineSpacing = 8
    , spaceAbove = 18
    , spaceBelow = 18
    , indent = 0
    , firstLineIndent = 0
    , fontSize = 12
    , borderWidth = Nothing
    , bgColor = RGB 1 1 1
    , fgColor = RGB 0.1 0.1 0.1
    , borderColor = Nothing
    , attrs = []
    }



-- HEADINGS


type Heading
    = Paragraph
    | Ordinary String -- block name
    | Verbatim String -- block name



-- METADATA TYPES


type alias ExprMeta =
    { begin : Int, end : Int, index : Int, id : String }


prefixIdInBlockMeta : String -> BlockMeta -> BlockMeta
prefixIdInBlockMeta prefix meta =
    { meta | id = prefix ++ String.replace prefix "e-" meta.id }


type alias BlockMeta =
    { position : Int
    , lineNumber : Int
    , numberOfLines : Int
    , id : String
    , messages : List String
    , sourceText : String
    , error : Maybe String
    }



-- CONCRETE TYPES


type alias Expression =
    Expr ExprMeta


getMeta : Expression -> ExprMeta
getMeta expr =
    case expr of
        Fun _ _ meta ->
            meta

        VFun _ _ meta ->
            meta

        Text _ meta ->
            meta


setMeta : ExprMeta -> Expression -> Expression
setMeta meta expr =
    case expr of
        Fun name args _ ->
            Fun name args meta

        VFun name arg _ ->
            VFun name arg meta

        Text text _ ->
            Text text meta


{-|

    Transform meta so that begin and end are positions in the source text

-}
boost : Int -> ExprMeta -> ExprMeta
boost position meta =
    { meta | begin = meta.begin + position, end = meta.end + position }


boostBlock : ExpressionBlock -> ExpressionBlock
boostBlock block =
    updateMetaInBlock (boost block.meta.position) block


updateMeta : (ExprMeta -> ExprMeta) -> Expression -> Expression
updateMeta update expr =
    setMeta (update (getMeta expr)) expr


updateMetaInBlock : (ExprMeta -> ExprMeta) -> ExpressionBlock -> ExpressionBlock
updateMetaInBlock updater block =
    let
        newBody =
            case block.body of
                Left str ->
                    Left str

                Right exprs ->
                    Right (List.map (updateMeta updater) exprs)
    in
    { block | body = newBody }


{-| A block whose content is a list of strings.
-}
type alias PrimitiveBlock =
    Block (List String) BlockMeta


{-| A block whose content is a list of expressions.
-}
type alias ExpressionBlock =
    Block (Either String (List Expression)) BlockMeta


getMetaFromBlock : ExpressionBlock -> Maybe ExprMeta
getMetaFromBlock block =
    case block.body of
        Left _ ->
            Nothing

        Right exprList ->
            List.head exprList
                |> Maybe.map getMeta


getIdFromBlock : ExpressionBlock -> Maybe String
getIdFromBlock block =
    getMetaFromBlock block
        |> Maybe.map .id



-- SIMPLIFIED TYPES


type alias SimpleExpressionBlock =
    Block (Either String (List (Expr ()))) ()


type alias SimplePrimitiveBlock =
    Block (List String) ()



-- GENERIC SIMPLIFIERS


simplifyBlock : (contentA -> contentB) -> Block contentA blockMeta -> Block contentB ()
simplifyBlock simplifyContent block =
    { heading = block.heading
    , indent = block.indent
    , args = block.args
    , properties = block.properties
    , firstLine = block.firstLine
    , body = simplifyContent block.body
    , meta = ()
    , style = block.style
    }


simplifyExpr : Expr meta -> Expr ()
simplifyExpr expr =
    case expr of
        Fun name args _ ->
            Fun name (List.map simplifyExpr args) ()

        VFun name arg _ ->
            VFun name arg ()

        Text text _ ->
            Text text ()



-- CONCRETE SIMPLIFIERS


simplifyForest : List (Tree ExpressionBlock) -> List (Tree SimpleExpressionBlock)
simplifyForest forest =
    List.map simplifyTree forest


simplifyTree : Tree ExpressionBlock -> Tree SimpleExpressionBlock
simplifyTree tree =
    Tree.mapValues simplifyExpressionBlock tree


simplifyExpressionBlock : ExpressionBlock -> SimpleExpressionBlock
simplifyExpressionBlock block =
    let
        simplifyContent : Either String (List (Expr exprMeta)) -> Either String (List (Expr ()))
        simplifyContent content =
            case content of
                Left str ->
                    Left str

                Right exprs ->
                    Right (List.map simplifyExpr exprs)
    in
    simplifyBlock simplifyContent block


simplifyPrimitiveBlock : PrimitiveBlock -> SimplePrimitiveBlock
simplifyPrimitiveBlock block =
    simplifyBlock identity block



-- VALUES


primitiveBlockEmpty : PrimitiveBlock
primitiveBlockEmpty =
    { heading = Paragraph
    , indent = 0
    , args = []
    , properties = Dict.empty
    , firstLine = ""
    , body = []
    , meta = emptyBlockMeta
    , style = Nothing
    }


expressionBlockEmpty : ExpressionBlock
expressionBlockEmpty =
    { heading = Paragraph
    , indent = 0
    , args = []
    , properties = Dict.empty
    , firstLine = ""
    , body = Right []
    , meta = emptyBlockMeta
    , style = Nothing
    }


emptyBlockMeta =
    { position = 0
    , lineNumber = 0
    , numberOfLines = 0
    , id = ""
    , messages = []
    , sourceText = ""
    , error = Nothing
    }



-- HELPERS


getName : ExpressionBlock -> Maybe String
getName block =
    getNameFromHeading block.heading


setName : String -> ExpressionBlock -> ExpressionBlock
setName name block =
    case block.heading of
        Paragraph ->
            block

        Ordinary _ ->
            { block | heading = Ordinary name }

        Verbatim _ ->
            { block | heading = Verbatim name }


getNameFromHeading : Heading -> Maybe String
getNameFromHeading heading =
    case heading of
        Paragraph ->
            Nothing

        Ordinary name ->
            Just name

        Verbatim name ->
            Just name


getExpressionContent : ExpressionBlock -> List Expression
getExpressionContent block =
    case block.body of
        Left _ ->
            []

        Right exprs ->
            exprs


getVerbatimContent : ExpressionBlock -> Maybe String
getVerbatimContent block =
    case block.body of
        Left str ->
            Just str

        Right _ ->
            Nothing


getFunctionName : Expression -> Maybe String
getFunctionName expression =
    case expression of
        Fun name _ _ ->
            Just name

        VFun _ _ _ ->
            Nothing

        Text _ _ ->
            Nothing
