/*
 * unpacking API
 *
 * No description provided (generated by Openapi Generator https://github.com/openapitools/openapi-generator)
 *
 * The version of the OpenAPI document: 0.1.0
 * 
 * Generated by: https://openapi-generator.tech
 */




#[derive(Clone, Debug, PartialEq, Default, Serialize, Deserialize)]
pub struct CreateUser {
    #[serde(rename = "name")]
    pub name: String,
    #[serde(rename = "role")]
    pub role: crate::models::Role,
    #[serde(rename = "email")]
    pub email: String,
    #[serde(rename = "password")]
    pub password: String,
}

impl CreateUser {
    pub fn new(name: String, role: crate::models::Role, email: String, password: String) -> CreateUser {
        CreateUser {
            name,
            role,
            email,
            password,
        }
    }
}


