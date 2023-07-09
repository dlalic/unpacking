module Shared exposing
    ( Flags
    , Model
    , Msg
    , Window
    , init
    , subscriptions
    , update
    )

import Api
import Api.Data exposing (encodeTranslation)
import Api.Request.Default exposing (readAllTranslations)
import Browser.Events as Events
import Gen.Route
import Http
import I18Next exposing (Translations, initialTranslations, translationsDecoder)
import Json.Decode as Decode
import Json.Encode as Encode
import Request exposing (Request)
import Storage exposing (Storage)


type alias Flags =
    { width : Int
    , height : Int
    , storage : Decode.Value
    }


type alias Model =
    { storage : Storage
    , translations : Translations
    , window : Window
    }


type alias Window =
    { width : Int, height : Int }


init : Request -> Flags -> ( Model, Cmd Msg )
init req flags =
    let
        model : Model
        model =
            { storage = Storage.fromJson flags.storage, translations = initialTranslations, window = { width = flags.width, height = flags.height } }
    in
    ( model
    , if model.storage.session /= Nothing && req.route == Gen.Route.SignIn then
        Request.replaceRoute Gen.Route.SignIn req

      else if model.translations == initialTranslations then
        loadTranslations

      else
        Cmd.none
    )


type Msg
    = StorageUpdated Storage
    | LoadedTranslations (Result Http.Error Translations)
    | SetScreenSize Int Int


update : Request -> Msg -> Model -> ( Model, Cmd Msg )
update req msg model =
    case msg of
        StorageUpdated storage ->
            ( { model | storage = storage }
            , if Gen.Route.SignIn == req.route then
                Request.pushRoute Gen.Route.Home_ req

              else
                Cmd.none
            )

        LoadedTranslations (Ok translations) ->
            ( { model | translations = translations }, Cmd.none )

        LoadedTranslations (Err _) ->
            ( model, Cmd.none )

        SetScreenSize x y ->
            ( { model | window = { width = x, height = y } }, Cmd.none )


subscriptions : Request -> Model -> Sub Msg
subscriptions _ _ =
    Sub.batch [ Events.onResize (\values -> SetScreenSize values), Storage.load StorageUpdated ]


loadTranslations : Cmd Msg
loadTranslations =
    Api.send LoadedTranslations (Api.map mapTranslations readAllTranslations)


mapTranslations : Api.Data.Translation -> Translations
mapTranslations input =
    let
        encodedJson : Encode.Value
        encodedJson =
            encodeTranslation input
    in
    case Decode.decodeValue translationsDecoder encodedJson of
        Ok value ->
            value

        Err _ ->
            initialTranslations
