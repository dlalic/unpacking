port module Storage exposing
    ( Storage
    , fromJson
    , load
    , signIn
    , signOut
    )

import Domain.Session as Session exposing (Session)
import Json.Decode as Decode
import Json.Encode as Encode


type alias Storage =
    { session : Maybe Session
    }


fromJson : Decode.Value -> Storage
fromJson json =
    json
        |> Decode.decodeValue decoder
        |> Result.withDefault init


init : Storage
init =
    { session = Nothing
    }


decoder : Decode.Decoder Storage
decoder =
    Decode.map Storage
        (Decode.field "session" (Decode.maybe Session.decoder))


save : Storage -> Decode.Value
save storage =
    Encode.object
        [ ( "session"
          , storage.session
                |> Maybe.map Session.encode
                |> Maybe.withDefault Encode.null
          )
        ]


signIn : Session -> Storage -> Cmd msg
signIn session storage =
    saveToLocalStorage { storage | session = Just session }


signOut : Storage -> Cmd msg
signOut storage =
    saveToLocalStorage { storage | session = Nothing }


saveToLocalStorage : Storage -> Cmd msg
saveToLocalStorage =
    save >> save_


port save_ : Decode.Value -> Cmd msg


load : (Storage -> msg) -> Sub msg
load fromStorage =
    load_ (fromJson >> fromStorage)


port load_ : (Decode.Value -> msg) -> Sub msg
