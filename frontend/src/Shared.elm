module Shared exposing
    ( Flags
    , Model
    , Msg
    , decoder
    , init
    , subscriptions
    , update
    )

import Api
import Api.Data exposing (encodeTranslation, roleDecoder)
import Api.Request.Default exposing (readAllTranslations)
import Browser.Events as Events
import Dict
import Effect exposing (Effect)
import I18Next exposing (Translations, initialTranslations, translationsDecoder)
import Json.Decode
import Json.Encode
import Route exposing (Route)
import Route.Path
import Shared.Model
import Shared.Msg exposing (Msg(..))
import Uuid



-- FLAGS


type alias Flags =
    { user : Maybe Shared.Model.User
    , width : Int
    , height : Int
    }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.map3 Flags
        (Json.Decode.field "user" (Json.Decode.maybe userDecoder))
        (Json.Decode.field "width" Json.Decode.int)
        (Json.Decode.field "height" Json.Decode.int)


userDecoder : Json.Decode.Decoder Shared.Model.User
userDecoder =
    Json.Decode.map3 Shared.Model.User
        (Json.Decode.field "token" Json.Decode.string)
        (Json.Decode.field "id" Uuid.decoder)
        (Json.Decode.field "role" roleDecoder)



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    let
        flags : Flags
        flags =
            flagsResult
                |> Result.withDefault { user = Nothing, width = 0, height = 0 }
    in
    ( { user = flags.user, translations = initialTranslations, window = { width = flags.width, height = flags.height } }
    , Effect.sendCmd loadTranslations
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        Shared.Msg.SignIn user ->
            ( { model | user = Just user }
            , Effect.batch
                [ Effect.pushRoute
                    { path = Route.Path.Home_
                    , query = Dict.empty
                    , hash = Nothing
                    }
                , Effect.saveUser user
                ]
            )

        Shared.Msg.SignOut ->
            ( { model | user = Nothing }, Effect.clearUser )

        LoadedTranslations (Ok translations) ->
            ( { model | translations = translations }, Effect.none )

        LoadedTranslations (Err _) ->
            ( model, Effect.none )

        SetScreenSize x y ->
            ( { model | window = { width = x, height = y } }, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ _ =
    Events.onResize (\values -> SetScreenSize values)



-- TRANSLATIONS


loadTranslations : Cmd Msg
loadTranslations =
    Api.send LoadedTranslations (Api.map mapTranslations readAllTranslations)


mapTranslations : Api.Data.Translation -> Translations
mapTranslations input =
    let
        encodedJson : Json.Encode.Value
        encodedJson =
            encodeTranslation input
    in
    case Json.Decode.decodeValue translationsDecoder encodedJson of
        Ok value ->
            value

        Err _ ->
            initialTranslations
