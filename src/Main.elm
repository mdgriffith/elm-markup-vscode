port module Main exposing (main)

import Browser
import Html
import Json.Decode
import Json.Encode


editorMessageDecoder =
    Json.Decode.field "command" Json.Decode.string
        |> Json.Decode.andThen
            (\command ->
                if command == "ActiveTextEditor" then
                    Json.Decode.map SelectedFilename
                        (Json.Decode.field "fileName" Json.Decode.string)

                else if command == "ViewRange" then
                    Json.Decode.map2
                        (\fileName ranges ->
                            ViewedRanges
                                { fileName = fileName
                                , ranges = ranges
                                }
                        )
                        (Json.Decode.field "fileName" Json.Decode.string)
                        (Json.Decode.field "ranges" (Json.Decode.list range))

                else if command == "EditorSelection" then
                    Json.Decode.map2
                        (\fileName selections ->
                            CurrentSelections
                                { fileName = fileName
                                , selections = selections
                                }
                        )
                        (Json.Decode.field "fileName" Json.Decode.string)
                        (Json.Decode.field "selections" (Json.Decode.list selection))

                else if command == "RefreshEditor" then
                    Json.Decode.map3
                        (\fileName selections ranges ->
                            Refresh
                                { fileName = fileName
                                , selections = selections
                                , ranges = ranges
                                }
                        )
                        (Json.Decode.field "fileName" Json.Decode.string)
                        (Json.Decode.field "selections" (Json.Decode.list selection))
                        (Json.Decode.field "ranges" (Json.Decode.list range))

                else
                    Json.Decode.succeed NoOp
             -- { command: "ActiveTextEditor", fileName: editor.document.fileName }
            )


selection =
    Json.Decode.map2 Selection
        (Json.Decode.field "anchor" position)
        (Json.Decode.field "active" position)


range =
    Json.Decode.map2 Range
        (Json.Decode.field "start" position)
        (Json.Decode.field "end" position)


type alias Position =
    { row : Int
    , col : Int
    }


position =
    Json.Decode.map2 Position
        (Json.Decode.field "line" Json.Decode.int)
        (Json.Decode.field "character" Json.Decode.int)


type alias Model =
    { viewing :
        Maybe
            { file : String
            , visible : List Range
            , selections : List Selection
            }
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
    | Notify


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> init
        , update = update
        , view = view
        , subscriptions =
            \_ ->
                Sub.batch
                    [ editorChange EditorChange
                    ]
        }


init =
    ( { viewing = Nothing }, Cmd.none )


update msg model =
    case Debug.log "Message" msg of
        NoOp ->
            ( model, Cmd.none )

        EditorChange jsonString ->
            case Json.Decode.decodeValue editorMessageDecoder jsonString of
                Ok newMessage ->
                    update newMessage model

                Err error ->
                    let
                        _ =
                            Debug.log "json" error
                    in
                    ( model, Cmd.none )

        SelectedFilename filename ->
            let
                newViewing =
                    case model.viewing of
                        Nothing ->
                            Just { file = filename, visible = [], selections = [] }

                        Just existing ->
                            Just { existing | file = filename }
            in
            ( { model | viewing = newViewing }
            , Cmd.none
            )

        ViewedRanges viewed ->
            let
                newViewing =
                    case model.viewing of
                        Nothing ->
                            Just
                                { file = viewed.fileName
                                , visible = viewed.ranges
                                , selections = []
                                }

                        Just existing ->
                            Just
                                { existing
                                    | file = viewed.fileName
                                    , visible = viewed.ranges
                                }
            in
            ( { model | viewing = newViewing }
            , Cmd.none
            )

        CurrentSelections current ->
            let
                newViewing =
                    case model.viewing of
                        Nothing ->
                            Just
                                { file = current.fileName
                                , visible = []
                                , selections = current.selections
                                }

                        Just existing ->
                            Just
                                { existing
                                    | file = current.fileName
                                    , selections = current.selections
                                }
            in
            ( { model | viewing = newViewing }
            , Cmd.none
            )

        Refresh current ->
            let
                newViewing =
                    case model.viewing of
                        Nothing ->
                            Just
                                { file = current.fileName
                                , visible = current.ranges
                                , selections = current.selections
                                }

                        Just existing ->
                            Just
                                { existing
                                    | file = current.fileName
                                    , visible = current.ranges
                                    , selections = current.selections
                                }
            in
            ( { model | viewing = newViewing }
            , Cmd.none
            )

        Notify ->
            ( model, notify (Json.Encode.string "hi") )


view model =
    { title = "Elm Markup Live View"
    , body =
        [ case model.viewing of
            Nothing ->
                Html.text "No file detected."

            Just selected ->
                Html.div []
                    [ Html.div []
                        [ Html.text
                            ("file: " ++ viewFileName selected.file)
                        ]
                    , Html.div []
                        (List.map viewSelection selected.selections)
                    , Html.div []
                        (List.map viewRange selected.visible)
                    ]
        ]
    }


viewRange sel =
    Html.div []
        [ Html.div []
            [ Html.text "start"
            , viewPos sel.start
            ]
        , Html.div []
            [ Html.text "end"
            , viewPos sel.end
            ]
        ]


viewSelection sel =
    Html.div []
        [ Html.div []
            [ Html.text "anchor"
            , viewPos sel.anchor
            ]
        , Html.div []
            [ Html.text "active"
            , viewPos sel.active
            ]
        ]


viewPos { row, col } =
    Html.div []
        [ Html.div [] [ Html.text ("row: " ++ String.fromInt row) ]
        , Html.div [] [ Html.text ("col: " ++ String.fromInt col) ]
        ]



--     type alias Range =
--     { start : Position
--     , end : Position
--     }
-- type alias Selection =
--     { anchor : Position
--     , active : Position
--     }


viewFileName name =
    String.split "/" name
        |> List.reverse
        |> List.head
        |> Maybe.withDefault "Empty File"


port editorChange : (Json.Encode.Value -> msg) -> Sub msg


port notify : Json.Encode.Value -> Cmd msg
