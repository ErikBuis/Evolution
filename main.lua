--[[
    Dit programma is gemaakt door Erik Buis op 29/9/2018.
    De rode cirkels hebben een mutatie van 1.5%
    De groene cirkels hebben een mutatie van 1.0%
    De blauwe cirkels hebben een mutatie van 0.5%
]]

e = {}

--returns true if given touch is in given rect:
function e.pointinrect(x, y, x1, y1, x2, y2)
    return x>=x1 and y>=y1 and x<=x2 and y<=y2
end

--returns true if given touch is in given circle:
function e.pointincircle(x, y, xc, yc, r)
    return math.sqrt((x-xc)^2+(y-yc)^2) <= r
end

function CreatePopulation(SizePopulation, RunSimulTime, mutation, color)
    local population = {}
    population['mutation'] = mutation
    population['color'] = color

    for i = 1,SizePopulation do
        population[i] = {}
        population[i]['pos'] = {50, h/2}
        population[i]['speed'] = {0, 0} --this is also where the object is facing to, which will be displayed with a black line.
        population[i]['force'] = {}
        for j = 1,RunSimulTime do --in this loop, an individual will get a certain random force for every frame, so that it has a path to go to when the simulation is running for the first time:
            local force = math.random()*2
            local dir = math.random()*2*math.pi
            population[i]['force'][j] = {math.cos(dir)*force, math.sin(dir)*force}
        end
        population[i]['score'] = false
    end

    return population
end

function RunSimulation(PopulationsData, RunSimulTime, MaxSpeed, obstacles, target_coords) --this is also the drawing function
    for j = 1,RunSimulTime do
        draw.beginframe()
        draw.clear()
        --draw obstacles:
        for k, v in ipairs(obstacles) do
            draw.fillrect(v[1], v[2], v[3], v[4], colors.gray)
        end
        --draw target circle:
        draw.fillcircle(target_coords[1], target_coords[2], 10, colors.orange)

        for p = 1,#PopulationsData do
            local population = PopulationsData[p]['population']
            for i = 1,#population do
                local object_moveable = true
                --check if the new position of an individual (object) is in an obstacle. if not, it is not moveable (object_moveable=false):
                for k, v in ipairs(obstacles) do
                    if e.pointinrect(population[i]['pos'][1], population[i]['pos'][2], v[1], v[2], v[3], v[4]) then
                        object_moveable = false
                    end
                end
                --check if the new position is in the target circle:
                if e.pointincircle(population[i]['pos'][1], population[i]['pos'][2], target_coords[1], target_coords[2], 10) then
                    object_moveable = false
                end
                --check if the new position is out of the screen:
                if not e.pointinrect(population[i]['pos'][1], population[i]['pos'][2], 0, 0, w, h) then
                    object_moveable = false
                end
                --if the object is not in an obstacle or the target circle:
                if object_moveable then
                    --calculate new speed (I assume that 1 unit of time is equal to the time between 2 frames and the mass of an individual is equal to 1. Following F=m*a and v=a*t where m=1 and t=1, new_v = old_v + F):
                    population[i]['speed'][1] = population[i]['speed'][1] + population[i]['force'][j][1]
                    population[i]['speed'][2] = population[i]['speed'][2] + population[i]['force'][j][2]
                    --round down to MaxSpeed if nessesary:
                    local total_speed = math.sqrt(population[i]['speed'][1]^2 + population[i]['speed'][2]^2)
                    if total_speed > MaxSpeed then
                        population[i]['speed'][1] = population[i]['speed'][1]/(total_speed/MaxSpeed)
                        population[i]['speed'][2] = population[i]['speed'][2]/(total_speed/MaxSpeed)
                    end
                    --calculate new position (again assuming that t=1 so that new_s = old_s + v):
                    population[i]['pos'][1] = population[i]['pos'][1] + population[i]['speed'][1]
                    population[i]['pos'][2] = population[i]['pos'][2] + population[i]['speed'][2]
                end
                --draw individuals in population:
                draw.fillcircle(population[i]['pos'][1], population[i]['pos'][2], 4, population['color'])
                draw.line(population[i]['pos'][1], population[i]['pos'][2], population[i]['pos'][1] + population[i]['speed'][1]*5, population[i]['pos'][2] + population[i]['speed'][2]*5, colors.black) --*5 because you will be able to see the direction clearer.
            end
            PopulationsData[p]['population'] = population
        end
        draw.endframe()
    end

    return PopulationsData
end

function GetScore(population, target_coords)
    for i = 1,#population do
        local max_dis = math.sqrt(w^2+h^2)
        population[i]['score'] = (max_dis-math.sqrt((population[i]['pos'][1]-target_coords[1])^2+(population[i]['pos'][2]-target_coords[2])^2)) / max_dis --A value between 0 and 1, because you can power values this way. Because the individuals with a lower score will be taken down (in score value) even more than the ones with a higher score, the higher ones are “buffed” even more so that they end up with a relatively better score. The highest score will have the best chance to reproduce and pass its genes over in NewPopulation. I chose the power 10 here, because in experimentation, 7 was not enough and 12 was too much. There is no particular reason to choose exactly 10, 9 or 11 would have also been good.
        population[i]['score'] = population[i]['score']^10
    end
    return population
end

function NewPopulation(population, RunSimulTime)
    --Sorting all elements on their score. The highest score will be at the highest index in ParentChances.
    local ParentChances = {}
    for i = 1,#population do
        --There will only ever be at highest 100 times the same element in ParentChances, because the score was calculated to be between 0 and 1. This is displayed below with the *100 operation:
        for j = 1,math.ceil(population[i]['score']*100) do
            table.insert(ParentChances, i)
        end
    end

    --create a new population with kids of older parents, after all kids have been made, return this table as the new population:
    local new_population = CreatePopulation(#population, RunSimulTime, population['mutation'], population['color'])

    for i = 1,#new_population do
        --Get parents:
        local p1, p2 = ParentChances[math.random(#ParentChances)], ParentChances[math.random(#ParentChances)] --parent_x. This is now equal to the number of an element in the population. Remember: parents with a higher score are more likely to be picked out of the table, because they are more common in the table.

        --New child:
        for j = 1,RunSimulTime do
            --There are multiple ways to get new genes, but in this case, I use one of the two parents' DNA per frame. I can change it if I want to later:
            if math.random() <= 0.5 then
                new_population[i]['force'][j][1] = population[p1]['force'][j][1]
                new_population[i]['force'][j][2] = population[p1]['force'][j][2]
            else
                new_population[i]['force'][j][1] = population[p2]['force'][j][1]
                new_population[i]['force'][j][2] = population[p2]['force'][j][2]
            end
        end
    end

    return new_population
end

function ApplyMutation(population, RunSimulTime)
    for i = 1,#population do
        for j = 1,RunSimulTime do
            --if a mutation has to be executed, there will be a new force and a new direction assigned to one or more frame(s):
            if math.random() <= population['mutation'] then
                local force = math.random()*2
                local dir = math.random()*2*math.pi
                population[i]['force'][j] = {math.cos(dir)*force, math.sin(dir)*force}
            end
        end
    end

    return population
end

----------------------DEFAULT VARIABLES-------------------

draw.setscreen(1)
w, h = draw.getport()

local RunSimulTime = 300 --number of ticks in one simulation
local MaxSpeed = 5 --in pix/tick
local obstacles = {{300, 0, 320, 400}, {480, 350, 500, h}}
local target_coords = {w, h/2}
local PopulationsData = {{color=colors.red, mutation=0.015}, {color=colors.green, mutation=0.010}, {color=colors.blue, mutation=0.005}}
for k, v in ipairs(PopulationsData) do
    PopulationsData[k]['population'] = CreatePopulation(30, RunSimulTime, v['mutation'], v['color'])
end

--------------------------MAINLOOP------------------------

repeat
    PopulationsData = RunSimulation(PopulationsData, RunSimulTime, MaxSpeed, obstacles, target_coords)
    for k, v in ipairs(PopulationsData) do
        local population = v['population']
        population = GetScore(population, target_coords)
        population = NewPopulation(population, RunSimulTime)
        population = ApplyMutation(population, RunSimulTime)
        PopulationsData[k]['population'] = population
    end
until false
