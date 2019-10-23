import requests
import json
import sys

def authenticate(domain=None, user_name=None, password=None):
    data = {'user': {'user_name': user_name, 'password': password}}

    r = requests.post(
        domain + "/api/sessions", 
        json = data
    )

    if r.status_code == 201:
        return r.json()
    
    return {
        "error": "Can not authenticate user: " + user_name
    }

def get_rule_implementations_structures(domain=None, token=None):
    r = requests.get(
        domain + "/api/rule_implementations_structures", 
        headers = { "Authorization": "Bearer " + token }
    )

    if r.status_code == 403 or r.status_code == 500:
        return {
            "error": "status code: " + r.status_code
        }

    print(r.json())
    return list(r.json()["data"])

def insert_external_id(domain=None, token=None, rule_implementations=[]):
    results = []

    for rule_implementation in rule_implementations:
        rule_implementation_id = rule_implementation["id"]
        system_params = rule_implementation["system_params"]
        print(system_params)
        data = { "rule_implementation": { "system_params": system_params } }
        data_structure_id = "todo"

        r = requests.get(
            domain + "/api/data_structures/" + data_structure_id, 
            headers = { "Authorization": "Bearer " + token }
        )

        if r.status_code == 403 or r.status_code == 500:
            return {
                "error": "status code: " + r.status_code
            }

        print(r.json())
        return list(r.json()["data"])

        r = requests.post(
            domain + "/api/rule_implementations/" + rule_implementation_id, 
            json = data,
            headers = { "Authorization": "Bearer " + token }
        )

        results.append({ "status": r.status_code, "rule_implementation": resource_id })
    
    return results 

def main(domain, user_name, password):
    reply = authenticate(
        domain=domain, 
        user_name=user_name, 
        password=password
    )

    if "error" in reply:
        print(reply)
        return

    rule_implementations = get_rule_implementations_structures(
        domain=domain, 
        token=reply['token']
    )

    if "error" in reply:
        print(reply)
        return

    results = insert_external_id(
        domain=domain, 
        token=reply['token'], 
        rule_implementations=rule_implementations
    )

    failed = list(filter(lambda x: x["status"] != 201, results))

    if failed:
        print("Failed rule_implementations", failed)
    else:
        print("Success!!")


if __name__ == "__main__":
    # execute only if run as a script
    if len(sys.argv) != 4:
        print("Missing arguments")
    else:
        args = sys.argv
        main(args[1], args[2], args[3], args[4])