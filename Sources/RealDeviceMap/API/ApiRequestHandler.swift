//
//  ApiRequestHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSessionMySQL

class ApiRequestHandler {
    
    private static var sessionDriver = MySQLSessions()
    
    public static func handle(request: HTTPRequest, response: HTTPResponse, route: WebServer.APIPage) {
        
        switch route {
        case .getData:
            handleGetData(request: request, response: response)
        }
    }
    
    private static func handleGetData(request: HTTPRequest, response: HTTPResponse) {
        
        let minLat = request.param(name: "min_lat")?.toDouble()
        let maxLat = request.param(name: "max_lat")?.toDouble()
        let minLon = request.param(name: "min_lon")?.toDouble()
        let maxLon = request.param(name: "max_lon")?.toDouble()
        let showGyms = request.param(name: "show_gyms")?.toBool() ?? false
        let showRaids = request.param(name: "show_raids")?.toBool() ?? false
        let showPokestops = request.param(name: "show_pokestops")?.toBool() ?? false
        let showQuests = request.param(name: "show_quests")?.toBool() ?? false
        let showPokemon = request.param(name: "show_pokemon")?.toBool() ?? false
        let pokemonFilterExclude = (try? (request.param(name: "pokemon_filter_exclude") ?? "")?.jsonDecode() as? [Int]) ?? nil
        let showSpawnpoints =  request.param(name: "show_spawnpoints")?.toBool() ?? false
        let showDevices =  request.param(name: "show_devices")?.toBool() ?? false
        let showInstances =  request.param(name: "show_instances")?.toBool() ?? false
        let showPokemonFilter = request.param(name: "show_pokemon_filter")?.toBool() ?? false
        let formatted =  request.param(name: "formatted")?.toBool() ?? false
        let lastUpdate = request.param(name: "last_update")?.toUInt32() ?? 0
        let showAssignments = request.param(name: "show_assignments")?.toBool() ?? false
        
        if (showGyms || showRaids || showPokestops || showPokemon) &&
            (minLat == nil || maxLat == nil || minLon == nil || maxLon == nil) {
            response.respondWithError(status: .badRequest)
            return
        }
        
        var perms = [Group.Perm]()
        let sessionPerms = (request.session?.data["perms"] as? Int)?.toUInt32()
        if sessionPerms == nil {
            response.respondWithError(status: .unauthorized)
            return
        } else {
            perms = Group.Perm.numberToPerms(number: sessionPerms!)
        }
        
        let permViewMap = perms.contains(.viewMap)
        
        guard let mysql = DBController.global.mysql else {
            response.respondWithError(status: .internalServerError)
            return
        }
        
        var data = [String: Any]()
        let permShowRaid = perms.contains(.viewMapRaid)
        let permShowGym =  perms.contains(.viewMapGym)
        if (permViewMap && (showGyms && permShowGym || showRaids && permShowRaid)) {
            data["gyms"] = try? Gym.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, raidsOnly: !showGyms, showRaids: permShowRaid)
        }
        let permShowStops = perms.contains(.viewMapPokestop)
        let permShowQuests =  perms.contains(.viewMapQuest)
        if (permViewMap && (showPokestops && permShowStops || showQuests && permShowQuests)) {
            data["pokestops"] = try? Pokestop.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, questsOnly: !showPokestops, showQuests: permShowQuests)
        }
        if permViewMap && showPokemon && perms.contains(.viewMapPokemon){
            data["pokemon"] = try? Pokemon.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate, pokemonFilterExclude: pokemonFilterExclude)
        }
        if permViewMap && showSpawnpoints && perms.contains(.viewMapSpawnpoint){
            data["spawnpoints"] = try? SpawnPoint.getAll(mysql: mysql, minLat: minLat!, maxLat: maxLat!, minLon: minLon!, maxLon: maxLon!, updated: lastUpdate)
        }
        if permViewMap && showPokemonFilter {
            
            let hideString = Localizer.global.get(value: "filter_hide")
            let showString = Localizer.global.get(value: "filter_show")
            
            let smallString = Localizer.global.get(value: "filter_small")
            let normalString = Localizer.global.get(value: "filter_normal")
            let largeString = Localizer.global.get(value: "filter_large")
            let hugeString = Localizer.global.get(value: "filter_huge")
            
            var pokemonData = [[String: Any]]()
            for i in 1...WebReqeustHandler.maxPokemonId {
                
                let filter = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-off select-button-new" data-id="\(i)" data-type="pokemon" data-info="hide">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(hideString)
                        </label>
                        <label class="btn btn-sm btn-on select-button-new" data-id="\(i)" data-type="pokemon" data-info="show">
                            <input type="radio" name="options" id="show" autocomplete="off">\(showString)
                        </label>
                    </div>
                """
                
                
                let size = """
                    <div class="btn-group btn-group-toggle" data-toggle="buttons">
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="small">
                            <input type="radio" name="options" id="hide" autocomplete="off">\(smallString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="normal">
                            <input type="radio" name="options" id="show" autocomplete="off">\(normalString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="large">
                            <input type="radio" name="options" id="show" autocomplete="off">\(largeString)
                        </label>
                        <label class="btn btn-sm btn-size select-button-new" data-id="\(i)" data-type="pokemon" data-info="huge">
                            <input type="radio" name="options" id="show" autocomplete="off">\(hugeString)
                        </label>
                    </div>
                """
                
                pokemonData.append([
                    "pokemon_id": String(format: "%03d", i),
                    "pokemon_name": Localizer.global.get(value: "poke_\(i)") ,
                    "image": "<img class=\"lazy_load\" data-src=\"/static/img/pokemon/\(i).png\" style=\"height:50px; width:50px;\">",
                    "filter": filter,
                    "size": size
                ])
            }
            data["pokemon_filters"] = pokemonData
        }

        
        if showDevices && perms.contains(.adminSetting) {
            
            let devices = try? Device.getAll(mysql: mysql)
            var jsonArray = [[String: Any]]()
            
            if devices != nil {
                for device in devices! {
                    var deviceData = [String: Any]()
                    deviceData["uuid"] = device.uuid
                    deviceData["host"] = device.lastHost ?? ""
                    deviceData["instance"] = device.instanceName ?? ""
                    deviceData["username"] = device.accountUsername ?? ""
                    
                    if formatted {
                        let formattedDate: String
                        if device.lastSeen == 0 {
                            formattedDate = ""
                        } else {
                            let date = Date(timeIntervalSince1970: TimeInterval(device.lastSeen))
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm:ss dd.MM.yyy"
                            formatter.timeZone = Localizer.global.timeZone
                            formattedDate = formatter.string(from: date)
                        }
                        deviceData["last_seen"] = ["timestamp": device.lastSeen, "formatted": formattedDate]
                        deviceData["buttons"] = "<a href=\"/dashboard/device/assign/\(device.uuid.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Assign Instance</a>"
                    } else {
                        deviceData["last_seen"] = device.lastSeen
                    }
                    jsonArray.append(deviceData)
                }
            }
            data["devices"] = jsonArray
            
        }
        
        if showInstances && perms.contains(.adminSetting) {
            
            let instances = try? Instance.getAll(mysql: mysql)
            
            var jsonArray = [[String: Any]]()
            
            if instances != nil {
                for instance in instances! {
                    var instanceData = [String: Any]()
                    instanceData["name"] = instance.name
                    switch instance.type {
                    case .circleRaid:
                        instanceData["type"] = "Circle Raid"
                    case .circlePokemon:
                        instanceData["type"] = "Circle Pokemon"
                    case .autoQuest:
                        instanceData["type"] = "Auto Quest"
                    case .pokemonIV:
                        instanceData["type"] = "Pokemon IV"
                    }
                    
                    instanceData["status"] = InstanceController.global.getInstanceStatus(instance: instance)
                    
                    if formatted {
                        instanceData["buttons"] = "<a href=\"/dashboard/instance/edit/\(instance.name.encodeUrl()!)\" role=\"button\" class=\"btn btn-primary\">Edit Instance</a>"
                    }
                    jsonArray.append(instanceData)
                }
            }
            data["instances"] = jsonArray
            
        }
        
        if showAssignments && perms.contains(.adminSetting) {
            
            let assignments = try? Assignment.getAll(mysql: mysql)
            
            var jsonArray = [[String: Any]]()
            
            if assignments != nil {
                for assignment in assignments! {
                    var assignmentData = [String: Any]()
                    
                    assignmentData["instance_name"] = assignment.instanceName
                    assignmentData["device_uuid"] = assignment.deviceUUID

                    if formatted {
                        let formattedTime: String
                        if assignment.time == 0 {
                            formattedTime = "On Complete"
                        } else {
                            let times = assignment.time.secondsToHoursMinutesSeconds()
                            formattedTime = "\(String(format: "%02d", times.hours)):\(String(format: "%02d", times.minutes)):\(String(format: "%02d", times.seconds))"
                        }
                        assignmentData["time"] = ["timestamp": assignment.time as Any, "formatted": formattedTime]
                       
                        let instanceUUID = "\(assignment.instanceName.escaped())\\-\(assignment.deviceUUID.escaped())\\-\(assignment.time)"
                        assignmentData["buttons"] = "<a href=\"/dashboard/assignment/delete/\(instanceUUID.encodeUrl()!)\" role=\"button\" class=\"btn btn-danger\">Delete</a>"                    } else {
                        assignmentData["time"] = assignment.time as Any
                    }
                    
                    jsonArray.append(assignmentData)
                }
            }
            data["assignments"] = jsonArray
            
        }
        
        data["timestamp"] = Int(Date().timeIntervalSince1970)

        do {
            try response.respondWithData(data: data)
        } catch {
            response.respondWithError(status: .internalServerError)
            return
        }
    }
    
}
