module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Url
import Json.Decode exposing (Decoder, field, string, decodeValue, succeed, map2)



-- MAIN


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , assets : Result String Assets
    }

init : Json.Decode.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model key url (Result.mapError Json.Decode.errorToString
                         (decodeValue assetDecoder flags))
    , Cmd.none
    )

type alias Assets =
    { logo: String
    , buttonText : String
    }


assetDecoder : Decoder Assets
assetDecoder =
    map2 Assets
        (field "logo" string)
        (succeed "Click me!")


-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Amicus Auxilium"
    , body =
        case model.assets of
            Ok assets -> [ headerBar assets
                         , main_ []
                             [ sideBar
                             , h1 [] [ text "Howdy Y'all!" ] ]
                         ]
            Err msg -> [ main_ [] [ h1 [] [ text "Error"]
                                , p [] [ text msg ]
                                ]
                       ]
    }


headerBar : Assets -> Html Msg
headerBar assets =
    header []
        [ img [ class "logo", src assets.logo, alt "Amicus Auxilium" ] []
        ]

sideBar : Html Msg
sideBar =
    div [ class "sidebar" ] []
