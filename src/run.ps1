param(
    $startLat,
    $startLong,
    [bool]$debug
)
if ($debug -eq $true) {
    $DebugPreference = "Continue";
}

#______________________
$global:googleApiKey = "AIzaSyAiOQcujvU7WRxY0YkBRCbONlQ3_QqOf6g"; #--gmaps-key
$global:auth = "ptc";         #--auth-service "ptc" or "google"
$global:dbPassword = "admin123"; #--pokel-pass
$global:stepLimit = 22;     #--step-limit
$global:threads = 3;          #--num-threads
$global:scanDelay = 0.9;      #--scan-delay
$global:no_server = $true;    #--no-server
$global:no_pokemons = $false; #--no-pokemons
$global:no_gyms = $true;      #--no-gyms
$global:no_pokestops = $true; #--no-pokestops
$global:hostURL = "0.0.0.0";  #--host
$global:startCoords = [Coords]::new(53.1323617,23.1445592);
$global:stepRadius = 100;
#______________________
$global:port; #--port
$global:portStart = 5000;
$global:username = "alfonskraweznik"; #--username
$global:usernameSufixes = @("")+@(2..9);
$global:password = "admin123"; #--password
$global:location; #--location
#______________________
$global:ConEmuPath= "D:\Programy\ConEmuPack.160707\ConEmu64.Exe";
$global:PokemonGoMapPath = "C:\Users\Sawik\Desktop\Pokemon Stuff\Pokemon go map from repo\runserver.py";
#______________________

[Functions]::parseParams($startLat, $startLong);
$commandsList = [Functions]::generateCommands();
$cmdString = [Functions]::generateCmdString($commandsList);
#$cmdString
powershell -Command $cmdString


Class Coords {
    [double]$lat;
    [double]$long;
    
    Coords([double]$lat, [double]$long) {
        $this.lat = $lat;
        $this.long = $long;
    }
}

Class Tiles {
    [System.Collections.ArrayList]$tiles;
    [int]$maxLength;

    Tiles($maxLength) {
        $this.tiles = [System.Collections.ArrayList]::new();
        $this.maxLength = $maxLength;
    }
    [void]push($x, $y) {
        if ($this.tiles.Count -lt $this.maxLength) {
            $this.tiles.Add(@($x, $y));
        }
    }
    [void]add4Sides($x, $y) {
        $this.push($x, $y);
        $this.push($x, -$y);
        $this.push(-$x, -$y);
        $this.push(-$x, $y);
    }
    [void]addYSides($x, $y) {
        $this.push($x, $y);
        $this.push($x, -$y);
    }
    [void]addXSides($x, $y) {
        $this.push($x, $y);
        $this.push(-$x, $y);
    }
}

Class Functions {
    static[void]parseParams($lat, $long) {
        if (($lat -is [double]) -and ($long -is [double])) {
            Write-Debug "Parsed input `$lat and `$long"
            $global:startCoords = [Coords]::new($lat, $long);
        }
    }
    static[System.Collections.ArrayList]generateCommands() {
        $commandsList =  [System.Collections.ArrayList]::new();
        $commandTemplate = "python '$global:PokemonGoMapPath' --gmaps-key $global:googleApiKey --auth-service $global:auth --pokel-pass $global:dbPassword --step-limit $global:stepLimit --num-threads $global:threads --scan-delay $global:scanDelay --host $global:hostURL --password $global:password";

        
        Write-Host $global:usernameSufixes.Length
        $coordsList = [Functions]::generateCoordsList($global:usernameSufixes.Length);
        foreach ($h in $coordsList) {
            Write-Host "$($h.lat), $($h.long)"
        }

        $counter = 0;
        foreach ($sufix in $global:usernameSufixes) {
            $thisCommand = $commandTemplate; #copy of template
            $thisUsername = "$global:username$sufix";
            $thisPort = $global:portStart++;
    
            $thisCommand += " --username $thisUsername --port $thisPort --location `'$($coordsList[$counter].lat), $($coordsList[$counter].long)`' ";

            if ($global:no_pokemons) {
                $thisCommand += " --no-pokemons ";
            }
            if ($global:no_gyms) {
                $thisCommand += " --no-gyms ";
            }
            if ($global:no_pokestops) {
                $thisCommand += " --no-pokestops ";
            }
            if ($counter -ne ($global:usernameSufixes.Length -1)) {
                if ($global:no_server) {
                    $thisCommand += " --no-server "
                }
            }

            #dodac znajdowanie lokalizacji po hexag

            $foo = $commandsList.Add($thisCommand);
            $counter++;
        }
        $commandsList
        return $commandsList;
    }
    static[string]generateCmdString($commandsList) {
        [string]$result = "$global:ConEmuPath -runlist ";
        $counter = 0;
        foreach ($command in $commandsList) {
            $result += "cmd.exe /k $command";
            if ($counter -lt $commandsList.Count -1) {
                $result += " '|||' ";
            }
            $counter++;
        }
        return $result;
    }
    static[Coords[]]generateCoordsList($amount) {
        $coordsList = [System.Collections.ArrayList]::new();
        $radius = $global:stepRadius * 2 * $global:stepLimit;
        $hexHeightMeters= $radius*[math]::Sqrt(3);
        $hexDiameterMeters = $radius * 2;
        $longXMeters = $hexHeightMeters + ($hexDiameterMeters / 2);
        Write-host $hexHeightMeters, $hexDiameterMeters;
        $hexHeightDegrees = [Functions]::distToDegrees($global:startCoords.lat,$global:startCoords.long, $hexHeightMeters)[0];
        $hexLongXDegrees = [Functions]::distToDegrees($global:startCoords.lat,$global:startCoords.long, $longXMeters)[1];
        Write-host $hexHeightDegrees, $hexLongXDegrees;
        $tilesList = [Functions]::generateTiles($amount);

        foreach ($tile in $tilesList) {
            $tilelatFactor = $tile[1];
            $tileLongFactor = $tile[0];

            $calcLat = $global:startCoords.lat + ($tileLatFactor * $hexHeightDegrees);
            #Write-Host "$($global:startCoords.lat) + $($tileLatFactor) * $($tileLengthDegrees[0]) = $($calcLat)"
            $calcLong = $global:startCoords.long + ($tileLongFactor * $hexLongXDegrees);
            #Write-Host "$($global:startCoords.long) + $($tileLongFactor) * $($tileLengthDegrees[1]) = $($calcLong)"
            #Write-Host "-------------------------------------"

            $coord = [Coords]::new($calcLat,$calcLong);
            $coordsList.Add($coord);
        }
        
        return $coordsList;
    }
    static[array]generateTiles($qty) {
        $iterations = -1;
        $counter = 1;
        while($iterations -lt 0) {
            $calculated = 3 * $counter * ($counter -1) +1;
            if ($calculated -ge $qty) {
                $iterations = $counter;
            } else {
                $counter++;
            }
        }
        $maxLevel = $iterations;
        $startX = 0;
        $startY = 1;
        $coords = [Tiles]::new($qty);
        $coords.push(0,0);

        for ($p = 0; $p -lt $maxLevel -1; $p++) {
            $coordX = $startX;
            $coordY = $startY + $p;
            $currentLevel = $p + 2;
            $coords.addYSides($coordX, $coordY);

            for ($i = 0; $i -lt $currentLevel -1; $i++) {
                $coordX += 0.5;
                $coordY -= 0.5;
                $coords.add4Sides($coordX, $coordY);
            }

            for ($i = 0; $i -lt $currentLevel -2; $i++) {
                $coordY -= 1;
                $coords.addXSides($coordX, $coordY);
            }
        }
        return $coords.tiles;

    }
    static[double[]]distToDegrees($lat, $long, $distance) {
        $startLat = $endLat = $lat;
        $startLong = $endLong = $long;
        $stepDistance = 0.00001;

        $countedDistance = 0;
        $tempLat = $endLat;
        while ($countedDistance -lt $distance) {
            $tempLat += $stepDistance;
            $countedDistance = [Functions]::measure($startLat, $startLong, $tempLat, $endLong);
        }
        $latDegreeDist = [math]::Abs($startLat - $tempLat);

        $countedDistance = 0;
        $tempLong = $endLong;
        while ($countedDistance -lt $distance) {
            $tempLong += $stepDistance;
            $countedDistance = [Functions]::measure($startLat, $startLong, $endLat, $tempLong);
        }
        $longDegreeDist = [math]::Abs($startLong - $tempLong);

        return @($latDegreeDist,$longDegreeDist);
    }
    static[double]measure($lat1, $lon1, $lat2, $lon2) {
        $r = 6378.137;
        $dLat = ($lat2 - $lat1) * [math]::PI / 180;
        $dLon = ($lon2 - $lon1) * [math]::PI / 180;
        $a = [math]::Sin($dLat/2) * [math]::sin($dLat/2) +
        [math]::Cos($lat1 * [math]::PI / 180) * [math]::Cos($lat2 * [math]::PI / 180) *
        [math]::Sin($dLon/2) * [math]::Sin($dLon/2);
        $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a));
        $d = $r * $c;
        return $d * 1000;
    }
}


#C:\Users\Sawik>D:\Programy\ConEmuPack.160707/ConEmu.exe -runlist cmd -new_console:a ^|^|^| cmd.exe /k dir ^|^|^| cmd -new_console

#C:\Users\Sawik>@echo "dupa"
#"dupa"

#C:\Users\Sawik>Echo hello
#hello

<#every sufix is appended to the username
examples:
@(1,4,6,3,2) -- suffixes: 1,4,6,3,2
@() - no sufixes
@("",1,2,3) -- no first sufix: ,1,2,3
@(1..5)+@(8) -- suffixes: 1,2,3,4,5,8#>

<#list of custom usernames
examples:
@() - no custom usernames
@("johny23","bobby")#>