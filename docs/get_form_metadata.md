Get form metadata

> ## Documentation Index
> Fetch the complete documentation index at: https://developers.asana.com/llms.txt
> Use this file to discover all available pages before exploring further.

# Get form metadata

_Note: The path is a placeholder. The actual path is determined by the configuration of the app component._

Get the metadata from the app server to render a form. <br> <br> <a href="https://d3ki9tyy5l5ruj.cloudfront.net/obj/65a45303b5fb79a69a322593627e3b9521c68ba1/ac-form-metadata.png">
  <img src="https://d3ki9tyy5l5ruj.cloudfront.net/obj/65a45303b5fb79a69a322593627e3b9521c68ba1/ac-form-metadata.png" alt="App components form metadata request flow"/>
</a>

<HTMLBlock>
  {`
  <style>#ReferencePlayground{display:none;}</style>
  `}
</HTMLBlock>

# OpenAPI definition

```json
{
  "openapi": "3.0.0",
  "info": {
    "description": "This is the interface for handling requests for [app components](https://developers.asana.com/docs/overview-of-app-components). This reference is generated from an [OpenAPI spec] (https://raw.githubusercontent.com/Asana/openapi/master/defs/app_components_oas.yaml).",
    "title": "App Components",
    "termsOfService": "https://asana.com/terms",
    "contact": {
      "name": "Asana Support",
      "url": "https://asana.com/support"
    },
    "license": {
      "name": "Apache 2.0",
      "url": "https://www.apache.org/licenses/LICENSE-2.0"
    },
    "version": "0.1",
    "x-docs-schema-whitelist": [
      "AttachedResourceResponse",
      "FormField-Checkbox",
      "FormField-Date",
      "FormField-Datetime",
      "FormField-Dropdown",
      "FormField-MultiLineText",
      "FormField-RadioButton",
      "FormField-RichText",
      "FormField-SingleLineText",
      "FormField-StaticText",
      "FormField-Typeahead",
      "FormMetadataResponse",
      "RanActionResponse",
      "WidgetFooter-CustomText",
      "WidgetFooter-Created",
      "WidgetFooter-Updated",
      "WidgetMetadataResponse",
      "WidgetField-DatetimeWithIcon",
      "WidgetField-Pill",
      "WidgetField-TextWithIcon",
      "TypeaheadListResponse",
      "TypeaheadItem",
      "FormValues",
      "BadRequestResponse",
      "UnauthorizedResponse",
      "ForbiddenResponse",
      "NotFoundResponse",
      "InternalServerErrorResponse"
    ]
  },
  "x-readme": {
    "explorer-enabled": false
  },
  "servers": [
    {
      "url": "{siteUrl}",
      "description": "Main endpoint."
    }
  ],
  "tags": [
    {
      "name": "Modal forms",
      "description": "The modal form is displayed when the user starts the flow to create a resource. Asana will make a signed request to the specified `form_metadata_url` in the configuration, and expect a response with the metadata needed to create the form. This process is also used for forms within rule actions."
    }
  ],
  "components": {
    "parameters": {
      "expires_at": {
        "name": "expires_at",
        "required": true,
        "in": "query",
        "schema": {
          "type": "string"
        },
        "description": "The time (in ISO 8601 date format) when the request should expire."
      },
      "user": {
        "name": "user",
        "required": true,
        "in": "query",
        "schema": {
          "type": "string"
        },
        "description": "The user GID this hook is coming from."
      },
      "task": {
        "name": "task",
        "required": true,
        "in": "query",
        "schema": {
          "type": "string"
        },
        "description": "The task GID this hook is coming from."
      },
      "workspace": {
        "name": "workspace",
        "required": true,
        "in": "query",
        "schema": {
          "type": "string"
        },
        "description": "The workspace GID this hook is coming from."
      }
    },
    "responses": {
      "BadRequest": {
        "description": "Bad request",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/BadRequestResponse"
            }
          }
        }
      },
      "Unauthorized": {
        "description": "Unauthorized",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/UnauthorizedResponse"
            }
          }
        }
      },
      "Forbidden": {
        "description": "Forbidden",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ForbiddenResponse"
            }
          }
        }
      },
      "NotFound": {
        "description": "Not found",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/NotFoundResponse"
            }
          }
        }
      },
      "InternalServerError": {
        "description": "Server error",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/InternalServerErrorResponse"
            }
          }
        }
      }
    },
    "schemas": {
      "BadRequestResponse": {
        "description": "An error response object indicating a bad request (i.e., a status code of `400`).",
        "type": "object",
        "properties": {
          "error": {
            "description": "The error to display.",
            "type": "string",
            "example": "Illegal or malformed request."
          }
        }
      },
      "ForbiddenResponse": {
        "description": "An error response object indicating a forbidden request (i.e., a status code of `403`).",
        "type": "object",
        "properties": {
          "error": {
            "description": "The error to display.",
            "type": "string",
            "example": "Access forbidden."
          }
        }
      },
      "InternalServerErrorResponse": {
        "description": "An error response object indicating a request that could not be found (i.e., a status code of `500`).",
        "type": "object",
        "properties": {
          "error": {
            "description": "The error to display.",
            "type": "string",
            "example": "Internal server error."
          }
        }
      },
      "FormMetadataResponse": {
        "description": "Contains the metadata that describes how to display and manage a form.",
        "type": "object",
        "required": [
          "metadata",
          "template"
        ],
        "properties": {
          "template": {
            "description": "The interface name and version of a distinct form UI layout. A `template` is directly associated with a particular `metadata` schema.",
            "type": "string",
            "enum": [
              "form_metadata_v0"
            ],
            "example": "form_metadata_v0"
          },
          "metadata": {
            "description": "The metadata (i.e., underlying definition) of a form. `metadata` must exist alongside a `template`, and its schema must be specific to the value of that `template`.",
            "type": "object",
            "required": [
              "fields",
              "title"
            ],
            "properties": {
              "title": {
                "description": "The title of the form, which is displayed at the top of the creation form",
                "type": "string",
                "example": "Create New Issue"
              },
              "fields": {
                "description": "An array of form field objects that are rendered in the order they are in the array. Limit of 30 fields.\n\nValid object schemas: [FormField-Checkbox](/reference/modal-forms#formfield-checkbox), [FormField-Date](/reference/modal-forms#formfield-date), [FormField-Datetime](/reference/modal-forms#formfield-datetime), [FormField-Dropdown](/reference/modal-forms#formfield-dropdown), [FormField-MultiLineText](/reference/modal-forms#formfield-multilinetext), [FormField-RadioButton](/reference/modal-forms#formfield-radiobutton), [FormField-RichText](/reference/modal-forms#formfield-richtext), [FormField-SingleLineText](/reference/modal-forms#formfield-singlelinetext), [FormField-StaticText](/reference/modal-forms#formfield-statictext), [FormField-Typeahead](/reference/modal-forms#formfield-typeahead)",
                "type": "array"
              },
              "on_submit_callback": {
                "description": "The URL to `POST` the form to when the user clicks the submit button. If this is field is omitted then the submission button will be disabled. This is useful if the user must enter information in a watched field first, such as to show additional fields.",
                "type": "string",
                "example": "https://www.example.com/on_submit"
              },
              "on_change_callback": {
                "description": "The URL to `POST` the form to whenever watched field values are changed.",
                "type": "string",
                "example": "https://www.example.com/on_change"
              }
            }
          }
        }
      },
      "NotFoundResponse": {
        "description": "An error response object indicating a request that could not be found (i.e., a status code of `404`).",
        "type": "object",
        "properties": {
          "error": {
            "description": "The error to display.",
            "type": "string",
            "example": "Not found."
          }
        }
      },
      "UnauthorizedResponse": {
        "description": "An error response object indicating a unauthorized request (i.e., a status code of `401`).",
        "type": "object",
        "properties": {
          "error": {
            "description": "The error to display.",
            "type": "string",
            "example": "Authorization required."
          }
        }
      }
    }
  },
  "paths": {
    "/form_metadata_url_path_placeholder": {
      "parameters": [
        {
          "$ref": "#/components/parameters/workspace"
        },
        {
          "$ref": "#/components/parameters/task"
        },
        {
          "$ref": "#/components/parameters/user"
        },
        {
          "$ref": "#/components/parameters/expires_at"
        }
      ],
      "get": {
        "summary": "Get form metadata",
        "description": "_Note: The path is a placeholder. The actual path is determined by the configuration of the app component._\n\nGet the metadata from the app server to render a form. <br> <br> <a href=\"https://d3ki9tyy5l5ruj.cloudfront.net/obj/65a45303b5fb79a69a322593627e3b9521c68ba1/ac-form-metadata.png\">\n  <img src=\"https://d3ki9tyy5l5ruj.cloudfront.net/obj/65a45303b5fb79a69a322593627e3b9521c68ba1/ac-form-metadata.png\" alt=\"App components form metadata request flow\"/>\n</a>",
        "tags": [
          "Modal forms"
        ],
        "operationId": "getFormMetadata",
        "responses": {
          "200": {
            "description": "Successfully retrieved the metadata for a single form.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/FormMetadataResponse"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/BadRequest"
          },
          "401": {
            "$ref": "#/components/responses/Unauthorized"
          },
          "403": {
            "$ref": "#/components/responses/Forbidden"
          },
          "404": {
            "$ref": "#/components/responses/NotFound"
          },
          "500": {
            "$ref": "#/components/responses/InternalServerError"
          }
        }
      }
    }
  }
}
```