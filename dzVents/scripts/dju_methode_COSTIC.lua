--[[   
~/domoticz/scripts/dzVents/scripts/dju_methode_COSTIC.lua
auteur : papoo
MAJ : 23/02/2019
création : 27/12/2018
Principe :
Calculer, via l'information température d'une sonde extérieure, les Degrés jour Chauffage méthode COSTIC
Renseignez le nom de votre sonde extérieure dans la variable local device_temp_ext
Créez un custom device counter ou custom sensor, inscrivez son non dans la variable local cpt_djc

Un degré jour est calculé à partir des températures météorologiques extrêmes du lieu et du jour J : 
- Tn : température minimale du jour J mesurée à 2 mètres du sol sous abri et relevée entre J-1 (la veille) à 18h et J à 18h UTC. 
- Tx : température maximale du jour J mesurée à 2 mètres du sol sous abri et relevée entre J à 6h et J+1 (le lendemain) à 6h UTC. 
- S : seuil de température de référence choisi. 
- Moy = (Tn + Tx)/2 Température Moyenne de la journée
Pour un calcul de déficits  de température par rapport au seuil choisi : 
- Si S > TX (cas fréquent en hiver) : DJ = S - Moy 
- Si S ≤ TN (cas exceptionnel en début ou en fin de saison de chauffe) : DJ = 0 
- Si TN < S ≤ TX (cas possible en début ou en fin de saison de chauffe) : DJ = ( S – TN ) * (0.08 + 0.42 * ( S –TN ) / ( TX – TN ))


https://github.com/papo-o/domoticz_scripts/blob/master/dzVents/scripts/dju_methode_COSTIC.lua
--]]
--------------------------------------------
------------ Variables à éditer ------------
-------------------------------------------- 

local device_temp_ext       = 'Temperature exterieure' 	-- nom (entre ' ') ou idx  de la sonde de température/humidité extérieure                           
local cpt_djc               = 'DJU méthode COSTIC' 		-- nom du  dummy compteur DJC en degré
local S                     = 18                        -- seuil de température de non chauffage, par convention : 18°C

--------------------------------------------
----------- Fin variables à éditer ---------
-------------------------------------------- 

local scriptName            = 'DJU Méthode COSTIC'
local scriptVersion         = '2.7'
local djc                   = nil
local Txj                   = nil
local Tnj                   = nil
local moy                   = nil

return {
    active  = true,
    on = {
        timer   = { 'at 06:02', 'at 18:02' },
		--timer   = {'at 06:08 on 01/10-31/12' , 'at 18:02 on 01/10-31/12', 'at 06:08 on 01/01-20/05', 'at 18:02 on 01/01-20/05'},
        --timer   = {'every minute'},
        devices = { device_temp_ext } 	-- nom de la sonde de température/humidité extérieure'
    },
    
    logging =   {   -- level    =   domoticz.LOG_DEBUG,
                    -- level    =   domoticz.LOG_INFO,             -- Seulement un niveau peut être actif; commenter les autres
                    -- level    =   domoticz.LOG_ERROR,            -- Only one level can be active; comment others    
                    -- level    =   domoticz.LOG_MODULE_EXEC_INFO,

    marker = scriptName..' v'..scriptVersion 
    },
    
    data = { 								
        temperatures    = { history = true, maxItems = 12972, maxHours = 36, maxMinutes = 2 },-- un enregistrement toutes les dix secondes sur 2162 minutes
        Tn              = { history = true, maxItems = 1 },
    },
    
  execute = function(domoticz, item)

        --if (item.device == device_temp_ext) then
            local temperature = domoticz.devices(device_temp_ext).temperature        
            domoticz.log("--- --- --- Température Ext :     ".. tostring(domoticz.utils.round(temperature, 2)) .." °C", domoticz.LOG_DEBUG)
            -- add new data
            domoticz.data.temperatures.add(temperature)
            domoticz.log("--- --- --- nombre d\'heure depuis la dernière maj de Tn : ".. tostring(domoticz.data.Tn.getLatest().time.hoursAgo), domoticz.LOG_DEBUG)
            if domoticz.data.Tn == nil or tonumber(domoticz.data.Tn.getLatest().time.hoursAgo) > 25 then
                tn = domoticz.data.temperatures.minSince('24:02:00')
                domoticz.log("--- --- --- température minimale du jour :     ".. tostring(tn) .." °C", domoticz.LOG_DEBUG)
                domoticz.data.Tn.add(tn) 
            end
        --end
        if (item.trigger == 'at 06:02') then
		--if (item.trigger == 'at 06:02 on 01/10-31/12' or item.trigger == 'at 06:02 on 01/01-20/05') then
            local tn = domoticz.data.temperatures.minSince('24:02:00')
            domoticz.log("--- --- --- température minimale du jour :     ".. tostring(tn) .." °C", domoticz.LOG_DEBUG)
            domoticz.data.Tn.add(tn)            
        
        end
        if (item.trigger == 'at 18:02') then
		--if (item.trigger == 'at 18:02 on 01/10-31/12' or item.trigger == 'at 18:02 on 01/01-20/05') then
            Txj = domoticz.data.temperatures.maxSince('24:02:00')
            domoticz.log("--- --- --- température maximale du jour : ".. tostring(Txj) .." °C", domoticz.LOG_DEBUG)
            domoticz.log("--- --- --- test : ".. tostring(domoticz.data.Tn.getLatest().time.hoursAgo), domoticz.LOG_DEBUG)
            Tnj = domoticz.data.Tn.getLatest().data
            domoticz.log("--- --- --- température minimale du jour : ".. tostring(Tnj) .." °C", domoticz.LOG_DEBUG)
            moy = (Txj+Tnj)/2
            domoticz.log("--- --- --- température moyenne du jour  : ".. tostring(moy) .." °C", domoticz.LOG_DEBUG)
        
            if (S > Txj) then 
                djc = domoticz.utils.round(S - moy,0)
                domoticz.log("--- --- --- Le Seuil de ".. tostring(S) .."°C est supérieur à la température maximum atteinte lors des dernières 24 heures (".. tostring(Txj) .."°C)", domoticz.LOG_DEBUG)
                domoticz.log("--- --- --- djc : " .. tostring(djc), domoticz.LOG_DEBUG)
            elseif Tnj < S and S < Txj then 
                local a = S - Tnj
                domoticz.log("--- --- --- a : "..tostring(a), domoticz.LOG_DEBUG)
                local b = Txj - Tnj
                domoticz.log("--- --- --- b : "..tostring(b), domoticz.LOG_DEBUG)
                djc = a * ( 0.08 + 0.42 * a / b )
                domoticz.log("--- --- --- djc : "..tostring(djc), domoticz.LOG_DEBUG)
                djc = domoticz.utils.round(djc,0)
                domoticz.log("--- --- --- Le Seuil de "..tostring(S)..")°C est supérieur à la température minimale ("..tostring(Tnj).."°C) et inférieur à la température maximum atteinte lors des dernières 24 heures (".. tostring(Txj) .."°C)", domoticz.LOG_DEBUG)
            elseif S <= Txj then
                djc = 0
                domoticz.log("--- --- --- Le Seuil de "..tostring(S)..")°C est inférieur à la température maximum atteinte lors des dernières 24 heures (".. tostring(Txj) .."°C)", domoticz.LOG_DEBUG)
            end
            local cpt_djc_index = domoticz.devices(cpt_djc).counter
            domoticz.log("--- --- --- compteur avant mise à jour ".. tostring(cpt_djc) .." : ".. tostring(cpt_djc_index) .." DJU", domoticz.LOG_DEBUG)
            
            if cpt_djc_index ~= nil then
                cpt_djc_index = tonumber(cpt_djc_index) + djc
            else
                cpt_djc_index = djc
            end    
            domoticz.log("--- --- --- mise à jour compteur ".. tostring(cpt_djc) .." : ".. tostring(cpt_djc_index) .." DJU", domoticz.LOG_DEBUG)
            if (domoticz.devices(cpt_djc).deviceSubType) == 'RFXMeter counter' then 
                domoticz.devices(cpt_djc).updateCounter(cpt_djc_index) 
            elseif (domoticz.devices(cpt_djc).deviceSubType) == 'Custom Sensor' then 
                domoticz.devices(cpt_djc).updateCustomSensor(cpt_djc_index)
            end
        end        


  end
}
