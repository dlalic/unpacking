module Forms.Validators exposing (ValidationField(..), currentPasswordValidator, emailValidator, nameValidator, passwordValidator, snippetValidator)

import I18Next exposing (Translations)
import Translations.Forms exposing (onLengthLessThan, onNameEmpty, onPasswordEmpty, onSnippetEmpty, onUsernameEmpty)
import Validate exposing (Validator, ifBlank, ifFalse)


type ValidationField
    = Name
    | Email
    | Password
    | Text


nameValidator : Translations -> Validator ( ValidationField, String ) { a | name : String }
nameValidator translations =
    Validate.firstError
        [ ifBlank .name ( Name, onNameEmpty translations )
        , ifNotMinimumLength .name 1 ( Name, onLengthLessThan translations "1" )
        ]


emailValidator : Translations -> Validator ( ValidationField, String ) { a | email : String }
emailValidator translations =
    Validate.firstError
        [ ifBlank .email ( Email, onUsernameEmpty translations )
        , ifNotMinimumLength .email 6 ( Email, onLengthLessThan translations "6" )
        ]


currentPasswordValidator : Translations -> Validator ( ValidationField, String ) { a | password : String }
currentPasswordValidator translations =
    ifBlank .password ( Password, onPasswordEmpty translations )


passwordValidator : Translations -> Validator ( ValidationField, String ) { a | password : String }
passwordValidator translations =
    Validate.firstError
        [ ifBlank .password ( Password, onPasswordEmpty translations )
        , ifNotMinimumLength .password 6 ( Password, onLengthLessThan translations "6" )
        ]


snippetValidator : Translations -> Validator ( ValidationField, String ) { a | text : String }
snippetValidator translations =
    Validate.firstError
        [ ifBlank .text ( Text, onSnippetEmpty translations )
        , ifNotMinimumLength .text 1 ( Text, onLengthLessThan translations "1" )
        ]


ifNotMinimumLength : (subject -> String) -> Int -> error -> Validator error subject
ifNotMinimumLength subjectToString min error =
    ifFalse (\subject -> isMinimumLength (subjectToString subject) min) error


isMinimumLength : String -> Int -> Bool
isMinimumLength str min =
    String.length str >= min
