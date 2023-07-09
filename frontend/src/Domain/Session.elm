module Domain.Session exposing (Session, decoder, encode)

import Api.Data exposing (Role, encodeRole, roleDecoder)
import Json.Decode as Decode
import Json.Encode as Encode
import Uuid exposing (Uuid)


type alias Session =
    { token : String
    , id : Uuid
    , role : Role
    }


decoder : Decode.Decoder Session
decoder =
    Decode.map3 Session
        (Decode.field "token" Decode.string)
        (Decode.field "id" Uuid.decoder)
        (Decode.field "role" roleDecoder)


encode : Session -> Decode.Value
encode session =
    Encode.object
        [ ( "token", Encode.string session.token )
        , ( "id", Uuid.encode session.id )
        , ( "role", encodeRole session.role )
        ]
