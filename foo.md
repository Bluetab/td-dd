- [X] test/td_dd_web/controllers/search_controller_test.exs:39
- [X] test/td_dq_web/controllers/rule_controller_test.exs:185
- [X] test/td_dd_web/controllers/search_controller_test.exs:39
- [X] test/td_dd/data_structures/structure_note_test.exs:66
- [X] test/td_dd/data_structures/validation_test.exs:17

- [.] test/td_dd/data_structures/bulk_update_test.exs:180
- [X] test/td_dd/data_structures/bulk_update_test.exs:262

# TD-4166

- [ ] Revisión/limpieza de código
- [ ] Campo virtual en la vista

...

- [ ] Opción menú grants específica y mover lo de data catalog
    - [ ] My grants
    - [ ] My grant requests
- [ ] 

my grant requests, columnas
- no poner usuario
- estructura a la que has pedido acceso: nombre y path sería lo suyo
- estado
- fecha de última actualización
- configurable: columna concreta del metadata

- [X] kong


# TD-4076
​
- [X] GrantRequestStatus approved/rejected/whatever según las approvals
- [X] Initial status PENDING on create_grant_request
- [X] Quitar PUT/PATCH grant request
- [X] Quitar GrantRequestController.create?? + Grants.get_grant_request_group (without !)
- [X] Rename association grant_request_group to group
- [X] Validate current status before approval/rejection?
- [X] Parametrizar preload? Grants.do_list_grant_requests
- [X] updated_since / limit?
​
# Otras mierdas
​
- [-] Mover cosas de grants en TdDd.DataStructures.Audit a TdDd.Grants.Audit
- [ ] Mirar fallback_controller a ver si quitamos {:error, :, ""}
- [ ] Swagger
​
# TD-4077
- [X] Grant Request Id
- [X] Type of request (template used in the grant request group)
- [X] Request metadata (template content)
- [X] User who has requested the access
- [X] Structure to which access has been requested (external_id)
- [X] Filters to apply to the structure if any.
- [X] Request date
- [X] Structure Metadata
- [X] Probar eso ^^
- [X] approved -> processing controller nuevo
- [X] processing -> processed
- [x] refactor ApprovalController to GrantRequestApprovalController
- [ ] Comprobar que un service account puede filtrar por aprobados, sin
ningún tipo de permisos sobre dominios (verificar con Juan la parte de
permisos)
​
- [ ] Validaciones en lib/td_dd_web/views/grant_request_group_view.ex no
deberían de estar ahí -> comentarlo con el autor.


GrantRequestGroup
…

GrantRequest
current_status (virtual): string
updated_at: …

GrantRequestApproval
user_id: …
domain_id: …
is_rejection: …
grant_request_id: …
-> maybe_change_status
    -> {pending, rejected}, {pending, approved}

GrantRequestStatus
status: string
updated_at: …

