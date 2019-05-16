port module Main exposing (main)

import Browser
import Element
import Element.Font as Font
import Html
import Html.Attributes
import Json.Decode as Decode
import Json.Encode
import Model exposing (..)


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
    ( { viewing = Nothing
      , diagnostics = []
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "Message" msg of
        NoOp ->
            ( model, Cmd.none )

        EditorChange jsonString ->
            case Decode.decodeValue editorMessageDecoder jsonString of
                Ok newMessage ->
                    update newMessage model

                Err exactError ->
                    let
                        _ =
                            Debug.log "json" exactError
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

        RefreshDiagnostics diags ->
            ( { model | diagnostics = diags }
            , Cmd.none
              -- , highlightWords model.viewing diags
            )

        Notify ->
            ( model, notify (Json.Encode.string "hi") )


styleSheet =
    """
body {
    background-color: var(--vscode-editor-background);
    color: var(--vscode-editor-foreground);
    font-family: "Fira Code" !important;
    font-weight: var(--vscode-editor-font-weight);
    font-size: var(--vscode-editor-font-size);
    margin: 0;
    padding: 0 20px;
}
"""


view model =
    { title = "Elm Markup Live View"
    , body =
        [ Html.node "style" [] [ Html.text styleSheet ]
        , Html.div []
            (List.map viewError model.diagnostics)
        ]
    }


viewEditorFocus viewing =
    case viewing of
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


viewError current =
    let
        shortMarkupName =
            current.markupFile
                |> String.split "/"
                |> List.reverse
                |> List.head
                |> Maybe.withDefault "Unknown"
    in
    Html.div []
        [ Html.div []
            [ Html.div [ Html.Attributes.style "color" "yellow" ]
                [ Html.text shortMarkupName
                , Html.span [] [ Html.text " parsed with ", Html.text current.parserName ]
                ]
            ]
        , case current.errors of
            [] ->
                Html.div
                    [ Html.Attributes.style "white-space" "pre"
                    ]
                    [ Html.span
                        [ Html.Attributes.style "color" "green"
                        ]
                        [ Html.text "  ✓" ]
                    , Html.text " Successfully parsed!"
                    ]

            errors ->
                Html.div []
                    (List.map viewIssue errors)
        ]


viewIssue iss =
    Html.div [ Html.Attributes.style "white-space" "pre" ]
        [ Html.div [ Html.Attributes.style "color" "cyan" ]
            [ Html.text (fillToEighty ("-- " ++ String.toUpper iss.name ++ " ")) ]
        , Html.div []
            (List.map viewText iss.text)
        ]


fillToEighty str =
    let
        fill =
            String.repeat (80 - String.length str) "-"
    in
    str ++ fill


viewText txt =
    case txt.color of
        Nothing ->
            Html.text txt.text

        Just clr ->
            Html.span [ colorAttribute clr ] [ Html.text txt.text ]


colorAttribute clr =
    case clr of
        Yellow ->
            Html.Attributes.style "color" "yellow"

        Red ->
            Html.Attributes.style "color" "red"

        Cyan ->
            Html.Attributes.style "color" "cyan"


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


viewFileName name =
    String.split "/" name
        |> List.reverse
        |> List.head
        |> Maybe.withDefault "Empty File"


type Notification
    = HighlightWord
        { row : Int
        , start : Int
        , end : Int
        }
    | HighlightSection
        { startRow : Int
        , endRow : Int
        }


highlightWords viewing errors =
    notify <|
        Json.Encode.object
            [ ( "command", Json.Encode.string "highlight" )
            , ( "selections", Json.Encode.list encodeError errors )
            ]


encodeError error =
    Json.Encode.object
        [ ( "markupFile", Json.Encode.string error.markupFile )
        , ( "parserName", Json.Encode.string error.parserName )
        , ( "errors", Json.Encode.list encodeIssue error.errors )
        ]


encodeIssue issue =
    Json.Encode.object
        [ ( "focus", encodeFocus issue )
        , ( "name", Json.Encode.string issue.name )
        , ( "text", Json.Encode.list encodeText issue.text )
        ]


encodeText txt =
    Json.Encode.object
        [ ( "color", encodeColor txt.color )
        , ( "text", Json.Encode.string txt.text )
        ]


encodeColor clr =
    case clr of
        Nothing ->
            Json.Encode.string ""

        Just Red ->
            Json.Encode.string "red"

        Just Cyan ->
            Json.Encode.string "cyan"

        Just Yellow ->
            Json.Encode.string "yellow"


encodeFocus issue =
    Json.Encode.object
        [ ( "start", encodePos issue.focus.start )
        , ( "end", encodePos issue.focus.end )
        ]


encodePos pos =
    Json.Encode.object
        [ ( "row", Json.Encode.int pos.row )
        , ( "col", Json.Encode.int pos.col )
        ]


port editorChange : (Json.Encode.Value -> msg) -> Sub msg


port notify : Json.Encode.Value -> Cmd msg
