#!/usr/bin/env lua

seed_ts = {}
seed_ts.year = 2019
seed_ts.month = 6
seed_ts.day = 9
seed_ts.hour = 14
seed_ts.min = 30
seed_ts.sec = 15

ts_list = {}
keep_monthly = 6
keep_weekly = 4
keep_daily = 7 

for i = 1, 365, 1 do
    table.insert(ts_list, string.format("%u%02u%02u%02u%02u",
                                         seed_ts.year,
                                         seed_ts.month,
                                         seed_ts.day,
                                         seed_ts.hour,
                                         seed_ts.min)
            )
    seed_ts.day = seed_ts.day + 1
    seed_ts = os.date("*t", os.time(seed_ts))
end

-- ***********************************
-- code to test after this... test setup above
local function tstoTime(ts)
    local t = {}
    t.year = ts:sub(1,4)
    t.month = ts:sub(5,6)
    t.day = ts:sub(7,8)
    t.hour = ts:sub(9,10)
    t.min = ts:sub(11,12)
    t.sec = 0
return os.time(t)

end

local function prevDay(ts, days_cnt)
    local t = os.date("*t", tstoTime(ts) - (days_cnt*24*3600))
    return string.format("%u%02u%02u%02u%02u",
                         t.year,
                         t.month,
                         t.day,
                         t.hour,
                         t.min)
end

-- returns the most recent day of the previous week, initially, this is 
-- alwasy Saturday, but we can make that configurable...
-- Sunday is day 1...Saturday is 7
local function prevWeek(ts, week_cnt)
    local t = os.date("*t", tstoTime(ts))
    if t.wday ~= 7 then
        t = os.date("*t", os.time(t) - (24*3600)*(t.wday))
    end
    t = os.date("*t", os.time(t) - (week_cnt*(7*24*3600)))
    return string.format("%u%02u%02u%02u%02u",
                         t.year,
                         t.month,
                         t.day,
                         t.hour,
                         t.min)
end

-- return last day of month that is months_cnt back
local function prevMonth(ts, months_cnt)
    local t = os.date("*t",tstoTime(ts))
    local chk_lastday = os.date("*t",os.time({ year = t.year,
                                               month = t.month + 1,
                                               day = 0 }))
    if months_cnt ~= 0 then
        t = os.date("*t", os.time({year = t.year,
                                   month = t.month-months_cnt+1,
                                   day = 0,
                                   hour = t.hour,
                                   min = t.min}
                                   )
                )
    elseif t.day ~= chk_lastday.day then
        -- not the last day of the month, so adjust to last day of 
        -- previous month
        t = os.date("*t", os.time({year = t.year,
                                   month = t.month,
                                   day = 0,
                                   hour = t.hour,
                                   min = t.min}
                                   )
                )
    end


    return string.format("%u%02u%02u%02u%02u",
                         t.year,
                         t.month,
                         t.day,
                         t.hour,
                         t.min)
end

--[[
    Function to determine what timestamps to keep.  This was a mess to figure
    out.  Only managed it because I built the algorithm for 1 case and then
    worked backwards to generalize it to work for 3 different intervals- daily,
    weekly and monthly

    Params:  tlist- table of timestamps to work through
             keep_tbl- destination table for timestamps to keep
             max_keeps- maximum number of keeps
             ts_start- seed timestamp when determining the slice
                       of timestamps from the tlist
             interval- a function that takes a timestamp as its first
                       parameter and a interval count for the second
--]]
local function getKeeps(tlist, keep_tbl, max_keeps, ts_start, interval)
   
    local timestamps = {}
    local oldest = interval(ts_start, max_keeps)
    print("Max Keeps: "..max_keeps.."\nRange: "..ts_start.."<-->"..oldest)
    for _,v in ipairs(tlist) do
        if v <= ts_start and v >= oldest then
            table.insert(timestamps, v)
        end 
    end

    if #timestamps == 0 then return nil end

    local i = #timestamps
    local keep_cnt = 0
    local oldest_keep = nil
    repeat
        print("Keeping: "..timestamps[i])
        oldest_keep = timestamps[i]
        keep_tbl[timestamps[i]] = 1
        keep_cnt = keep_cnt + 1
        local tsref = interval(timestamps[i], 1)
        i = i - 1
        while (i ~= 0 and 
               timestamps[i] > tsref and
               keep_cnt ~= max_keeps) do
            i = i - 1
        end
    until i == 0 or keep_cnt == max_keeps

    return oldest_keep
end

-- #################################################
-- begin test run
sim_days = 90
for i = 1,sim_days,1 do

    print("DAY: "..i)
    table.sort(ts_list)
    for i,v in ipairs(ts_list) do print(i,v) end
    --print("Most Recent Timestamp: "..ts_list[#ts_list])
    keeps = {}
    oldest_keep = nil

    -- start with daily...
    --print("DAILIES")
    -- alwasy keep the most recent timestamp, which will be the last one
    if keep_daily ~= 0 then
        oldest_keep = getKeeps(ts_list, 
                               keeps, 
                               keep_daily, 
                               ts_list[#ts_list], 
                               prevDay
                              )
    end

    --print("WEEKLIES")
    if keep_weekly ~= 0 then
        oldest_keep = getKeeps(ts_list, 
                               keeps, 
                               keep_weekly,
                               prevWeek(prevDay(oldest_keep or ts_list[#ts_list], 1), 0), 
                               prevWeek
                              )
    end

    --print("MONTHLY")
    if keep_monthly ~= 0 then
        getKeeps(ts_list, 
                 keeps, 
                 keep_monthly, 
                 prevMonth(prevDay(oldest_keep or ts_list[#ts_list], 1), 0), 
                 prevMonth
                )
    end

    print("Removing: ")
    for _,v in ipairs(ts_list) do
        if not keeps[v] then print("\t"..v) end
    end
    
    ts_list = {}
    print("Keeping: ")
    for k,_ in pairs(keeps) do 
        print(k) 
        table.insert(ts_list,k)
    end

    -- simulate adding another timestamp
    new_ts = string.format("%u%02u%02u%02u%02u",
                                         seed_ts.year,
                                         seed_ts.month,
                                         seed_ts.day,
                                         seed_ts.hour,
                                         seed_ts.min)
    print("New Timestamp: "..new_ts)
    table.insert(ts_list, new_ts)
    seed_ts.day = seed_ts.day + 1
    seed_ts = os.date("*t", os.time(seed_ts))
 
end

print("##################################################")
print("#")
print("#     Test 2")
print("#")
print("##################################################")

-- *********************************************
-- test 2, build up to a full archive
ts_list = {}
keep_monthly = 6
keep_weekly = 4
keep_daily = 7 

seed_ts = {}
seed_ts.year = 2019
seed_ts.month = 6
seed_ts.day = 8
seed_ts.hour = 14
seed_ts.min = 30
seed_ts.sec = 15
sim_days = 93
for i = 1,sim_days,1 do

    -- simulate adding another timestamp
    new_ts = string.format("%u%02u%02u%02u%02u",
                                         seed_ts.year,
                                         seed_ts.month,
                                         seed_ts.day,
                                         seed_ts.hour,
                                         seed_ts.min)
    print("New Timestamp: "..new_ts)
    table.insert(ts_list, new_ts)

    print("DAY: "..i)
    table.sort(ts_list)
    for i,v in ipairs(ts_list) do print(i,v) end
    --print("Most Recent Timestamp: "..ts_list[#ts_list])
    keeps = {}
    oldest_keep = nil

    -- start with daily...
    --print("DAILIES")
    -- alwasy keep the most recent timestamp, which will be the last one
    if keep_daily ~= 0 then
        oldest_keep = getKeeps(ts_list, 
                               keeps, 
                               keep_daily, 
                               ts_list[#ts_list], 
                               prevDay
                              )
    end

    --print("WEEKLIES")
    if keep_weekly ~= 0 then
        oldest_keep = getKeeps(ts_list, 
                               keeps, 
                               keep_weekly,
                               prevWeek(prevDay(oldest_keep or ts_list[#ts_list], 1), 0), 
                               prevWeek
                              )
    end

    --print("MONTHLY")
    if keep_monthly ~= 0 then
        getKeeps(ts_list, 
                 keeps, 
                 keep_monthly, 
                 prevMonth(prevDay(oldest_keep or ts_list[#ts_list], 1), 0), 
                 prevMonth
                )
    end

    print("Removing: ")
    for _,v in ipairs(ts_list) do
        if not keeps[v] then print("\t"..v) end
    end
    
    ts_list = {}
    print("Keeping: ")
    for k,_ in pairs(keeps) do 
        print(k) 
        table.insert(ts_list,k)
    end

    -- setup next day ts entry
    seed_ts.day = seed_ts.day + 1
    seed_ts = os.date("*t", os.time(seed_ts))
 
end


