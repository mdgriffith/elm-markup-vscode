module Model exposing
    ( Color(..)
    , Error
    , Issue
    , Model
    , Msg(..)
    , Position
    , Range
    , Selection
    , Text
    , editorMessageDecoder
    , error
    , issue
    , maybeColor
    , position
    , range
    , selection
    , text
    )

import Json.Decode as Decode
import Json.Encode


editorMessageDecoder =
    Decode.field "command" Decode.string
        |> Decode.andThen
            (\command ->
                if command == "ActiveTextEditor" then
                    Decode.map SelectedFilename
                        (Decode.field "fileName" Decode.string)

                else if command == "ViewRange" then
                    Decode.map2
                        (\fileName ranges ->
                            ViewedRanges
                                { fileName = fileName
                                , ranges = ranges
                                }
                        )
                        (Decode.field "fileName" Decode.string)
                        (Decode.field "ranges" (Decode.list range))

                else if command == "EditorSelection" then
                    Decode.map2
                        (\fileName selections ->
                            CurrentSelections
                                { fileName = fileName
                                , selections = selections
                                }
                        )
                        (Decode.field "fileName" Decode.string)
                        (Decode.field "selections" (Decode.list selection))

                else if command == "RefreshEditor" then
                    Decode.map3
                        (\fileName selections ranges ->
                            Refresh
                                { fileName = fileName
                                , selections = selections
                                , ranges = ranges
                                }
                        )
                        (Decode.field "fileName" Decode.string)
                        (Decode.field "selections" (Decode.list selection))
                        (Decode.field "ranges" (Decode.list range))

                else if command == "Show" then
                    Decode.map RefreshDiagnostics
                        (Decode.field "json" (Decode.field "errors" (Decode.list error)))

                else
                    Decode.succeed NoOp
            )


type alias Error =
    { markupFile : String
    , parserName : String
    , errors : List Issue
    }


type alias Issue =
    { name : String
    , focus : Range
    , text : List Text
    }


type alias Text =
    { color : Maybe Color
    , text : String
    }


type Color
    = Red
    | Yellow
    | Cyan


error =
    Decode.map3 Error
        (Decode.field "sourcePath" Decode.string)
        (Decode.field "parser" Decode.string)
        (Decode.field "problems" (Decode.list issue))


issue =
    Decode.map3 Issue
        (Decode.field "title" Decode.string)
        (Decode.field "region" focus)
        (Decode.field "message" (Decode.list text))


text =
    Decode.map2 Text
        (Decode.field "color" maybeColor)
        (Decode.field "text" Decode.string)


maybeColor =
    Decode.nullable Decode.string
        |> Decode.andThen
            (\maybe ->
                case maybe of
                    Nothing ->
                        Decode.succeed Nothing

                    Just clr ->
                        case clr of
                            "yellow" ->
                                Decode.succeed (Just Yellow)

                            "red" ->
                                Decode.succeed (Just Red)

                            "cyan" ->
                                Decode.succeed (Just Cyan)

                            _ ->
                                Decode.fail ("Unknown Color: " ++ clr)
            )


selection =
    Decode.map2 Selection
        (Decode.field "anchor" position)
        (Decode.field "active" position)


range =
    Decode.map2 Range
        (Decode.field "start" position)
        (Decode.field "end" position)


type alias Position =
    { row : Int
    , col : Int
    }


position =
    Decode.map2 Position
        (Decode.field "line" Decode.int)
        (Decode.field "character" Decode.int)


focus =
    Decode.map2 Range
        (Decode.field "start" rowColPos)
        (Decode.field "end" rowColPos)


rowColPos =
    Decode.map2 Position
        -- offset is also present
        (Decode.field "line" Decode.int)
        (Decode.field "column" Decode.int)


type alias Model =
    { viewing :
        Maybe
            { file : String
            , visible : List Range
            , selections : List Selection
            }
    , diagnostics : List Error
    }


type alias Range =
    { start : Position
    , end : Position
    }


type alias Selection =
    { anchor : Position
    , active : Position
    }


type Msg
    = NoOp
    | EditorChange Json.Encode.Value
    | SelectedFilename String
    | ViewedRanges
        { fileName : String
        , ranges : List Range
        }
    | CurrentSelections
        { fileName : String
        , selections : List Selection
        }
    | Refresh
        { fileName : String
        , ranges : List Range
        , selections : List Selection
        }
    | RefreshDiagnostics (List Error)
    | Notify
