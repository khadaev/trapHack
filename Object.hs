module Object where

import Data
import Utils
import Changes
import Utils4all
import Stuff
import Utils4stuff

import UI.HSCurses.Curses (Key(..))
import Data.Set (member, empty, size)
import Data.Maybe (fromJust)

dropFirst :: Key -> World -> Bool -> (World, Bool)
dropFirst c world ignoreMessages = rez where
	objects = filter (\(x, _, _) -> KeyChar x == c) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) $ changeAction ' ' world, False)
		else (changeMon mon $ addMessage newMsg $ addItem (x, y, obj, cnt) 
			$ changeAction ' ' world, True)
	(_, obj, cnt) = head objects
	(x, y, oldmon) = head $ units world
	mon = delObj c $ oldmon
	newMsg =
		if ignoreMessages
		then ""
		else (name $ getFirst world) ++ " drop" ++ ending world ++ titleShow obj ++ "."

dropAll :: World -> World
dropAll world = foldr (\x y -> fst $ dropFirst x y True) world $ 
	map (KeyChar . first) $ inv $ getFirst world

quaffFirst :: Key -> World -> (World, Bool)
quaffFirst c world = rez where
	objects = filter (\(x, _, _) -> KeyChar x == c) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) $ changeAction ' ' world, False)
		else if (not $ isPotion obj)
		then (addMessage (
				if isPlayerNow world
				then "You don't know how to quaff it!"
				else ""
			) $ changeAction ' ' world, False)
		else (changeMon mon $ addMessage newMsg $ changeAction ' ' world, True)
	newMsg = (name $ getFirst world) ++ " quaff" ++ ending world ++ titleShow obj ++ "."
	[(_, obj, _)] = objects
	(x, y, oldMon) = head $ units world
	mon = delObj c $ act obj $ oldMon

zapFirst :: Key -> World -> (World, Bool)
zapFirst c world = rez where
	objects = filter (\(x, _, _) -> x == last (store world)) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) failWorld, False)
		else if (not $ isWand obj)
		then (addMessage (
				if isPlayerNow world
				then "You don't know how to zap it!"
				else ""
			) failWorld, False)
		else if dir c == Nothing
		then (addMessage (
				if isPlayerNow world
				then "It's not a direction!"
				else ""
			) failWorld, False)
		else if charge obj == 0
		then (addMessage (
				if isPlayerNow world
				then "This wand has no charge!"
				else ""
			) failWorld, True)
		else (changeMon mon $ changeStore (init $ store world) $ changeAction ' ' $ newMWorld, True)
	(x, y, _) = head $ units world
	(dx, dy) = fromJust $ dir c
	maybeCoords = dirs world (x, y, dx, dy)
	newMWorld = case maybeCoords of
		Just (xNew, yNew) -> zap world xNew yNew dx dy obj
		Nothing -> failWorld
	(_, _, oldMon) = head $ units newMWorld
	[(_, obj, _)] = objects
	mon = decChargeByKey (last $ store newMWorld) $ oldMon
	failWorld = changeStore (init $ store world) $ changeAction ' ' world

zap :: World -> Int -> Int -> Int -> Int -> Object -> World
zap world x y dx dy obj = 
	if (range obj == 0) || incorrect
	then world
	else if (dx == 0) && (dy == 0)
	then newMWorld
	else zap newMWorld xNew yNew dx dy $ decRange obj
	where
		(incorrect, (xNew, yNew)) = case dirs world (x, y, dx, dy) of
			Nothing -> (True, (0, 0))
			Just p -> (False, p)
		decRange :: Object -> Object
		decRange obj = Wand {
			title = title obj,
			act = act obj,
			range = range obj - 1,
			charge = charge obj
		}
		actFilter arg@(x', y', mon) = 
			if (x == x') && (y == y')
			then (x, y, act obj $ mon)
			else arg
		msgFilter (x', y', mon) = 
			if (x == x') && (y == y')
			then name mon ++ " was zapped! "
			else ""
		msg = foldl (++) "" $ map msgFilter $ units world
		newMWorld = addMessage msg $ changeMons (map actFilter $ units world) world

zapMon :: Key -> Char -> World -> World
zapMon dir obj world = fst $ zapFirst dir $
	changeStore (store world ++ [obj]) world

pickFirst :: World -> Maybe World
pickFirst world =
	if 0 == (size $ toPick world)
	then Nothing
	else Just World {
		units = (xMon, yMon, mon) : (tail $ units world),
		message = newMessage,
		items = newItems,
		action = ' ',
		stdgen = stdgen world,
		wave = wave world,
		toPick = empty,
		store = store world,
		worldmap = worldmap world,
		dirs = dirs world
	} where
	(xMon, yMon, oldMon) = head $ units world
	itemsWithIndices :: [((Int, Int, Object, Int), Int)]
	itemsWithIndices = addIndices (\(x', y' , _, _) -> xMon == x' && yMon == y') $ items world
	(itemsToPick, rest) = split (\(_, n) -> (n >= 0) && (member (alphabet !! n) $ toPick world)) itemsWithIndices
	mon = Monster {
		ai = ai oldMon,
		parts = parts oldMon,
		x = x oldMon,
		y = y oldMon,
		name = name oldMon,
		stddmg = stddmg oldMon,
		inv = addInvs (inv oldMon) $ map (\(_,_,a,b) -> (a,b)) $ map fst itemsToPick,
		slowness = slowness oldMon,
		time = time oldMon,
		weapon = weapon oldMon
	}
	newItems = map fst rest
	newMessage = oldMessage world ++ name mon ++ " pick" ++ ending world ++ "some objects."

trapFirst :: Key -> World -> (World, Bool)
trapFirst c world = rez where
	objects = filter (\(x, _, _) -> KeyChar x == c) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) failWorld, False)
		else if (not $ isTrap obj)
		then (addMessage (
				if isPlayerNow world
				then "It's not a trap!"
				else ""
			) failWorld, False)
		else (addMessage newMsg $ changeMon mon $ changeMap x y (num obj) $ changeAction ' ' $ world, True)
	(x, y, oldMon) = head $ units world
	[(_, obj, _)] = objects
	mon = delObj c oldMon
	failWorld = changeAction ' ' world
	newMsg = (name oldMon) ++ " set" ++ ending world ++ title obj ++ "."
	
untrapFirst :: World -> (World, Bool)
untrapFirst world = rez where
	rez =
		if not $ isUntrappable $ worldmap world !! x !! y
		then (addMessage (
				if isPlayerNow world
				then "It's nothing to untrap here!"
				else ""
			) failWorld, False)
		else (addItem (x, y, trap, 1) $ addMessage newMsg $ changeMap x y eMPTY 
			$ changeAction ' ' $ world, True)
	(x, y, mon) = head $ units world
	failWorld = changeAction ' ' world
	trap = trapFromTerrain $ worldmap world !! x !! y
	newMsg = (name mon) ++ " untrap" ++ ending world ++ title trap ++ "."
	
wieldFirst :: Key -> World -> (World, Bool)
wieldFirst c world = rez where
	objects = filter (\(x, _, _) -> KeyChar x == c) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) failWorld, False)
		else if not (isWeapon obj || isLauncher obj)
		then (addMessage (
				if isPlayerNow world
				then "You don't know how to wield it!"
				else ""
			) failWorld, False)
		else (addMessage newMsg $ changeMon mon $ changeAction ' ' $ world, True)
	(x, y, oldMon) = head $ units world
	[(_, obj, _)] = objects
	mon = changeWeapon c oldMon
	failWorld = changeAction ' ' world
	newMsg = (name oldMon) ++ " wield" ++ ending world ++ title obj ++ "."
	
fireFirst :: Key -> World -> (World, Bool)
fireFirst c world = rez where
	objects = filter (\(x, _, _) -> x == last (store world)) $ inv $ getFirst world
	wielded =
		if null listWield
		then Something
		else second $ head listWield
	listWield = filter (\(x, _, _) -> x == weapon oldMon) $ inv $ getFirst world
	rez =
		if (length objects == 0)
		then (addMessage (
				if isPlayerNow world
				then "You haven't this item!"
				else ""
			) failWorld, False)
		else if not $ isMissile obj
		then (addMessage (
				if isPlayerNow world
				then "You don't know how to fire it!"
				else ""
			) failWorld, False)
		else if (weapon oldMon == ' ') 
		then (addMessage (
				if isPlayerNow world
				then "You have no weapon!"
				else ""
			) failWorld, False)
		else if (not $ isLauncher wielded) || (launcher obj /= category wielded)
		then (addMessage (
				if isPlayerNow world
				then "You can't fire " ++ title obj ++ " by " ++ category wielded ++ "!"
				else ""
			) failWorld, False)
		else if dir c == Nothing
		then (addMessage (
				if isPlayerNow world
				then "It's not a direction!"
				else ""
			) failWorld, False)
		else (changeStore (init $ store world) $ changeAction ' ' newWorld, True)
	(x, y, oldMon) = head $ units world
	maybeCoords = dirs world (x, y, dx, dy)
	cnt = min n $ count wielded
	newWorld = case maybeCoords of
		Just (xNew, yNew) -> foldr (.) id (replicate cnt $ 
			fire xNew yNew dx dy obj) $ changeMon (fulldel oldMon) world
		Nothing -> failWorld
	Just (dx, dy) = dir c
	[(_, obj, n)] = objects
	fulldel = foldr (.) id $ replicate cnt $ delObj $ KeyChar $ last $ store world
	failWorld = changeStore (init $ store world) $ changeAction ' ' world
	
fire :: Int -> Int -> Int -> Int -> Object -> World -> World
fire x y dx dy obj world = 
	if incorrect
	then world
	else if null mons
	then fire xNew yNew dx dy obj world
	else newWorld
	where
		mons = filter (\(x', y', _) -> x == x' && y == y') $ units world
		(incorrect, (xNew, yNew)) = case dirs world (x, y, dx, dy) of
			Nothing -> (True, (0, 0))
			Just p -> (False, p)
		(newDmg, g) = objdmg obj world
		(newMon, g') = dmgRandom newDmg (third $ head mons) g
		actFilter arg@(x', y', mon) = 
			if (x == x') && (y == y')
			then (x', y', newMon)
			else arg
		msg = case newDmg of
			Nothing -> capitalize (title obj) ++ " misses."
			Just _ -> capitalize (title obj) ++ " hits " ++ name (third $ head mons) ++ "."
		newWorld = addMessage msg $ changeGen g' $ changeMons (map actFilter $ units world) world
		
fireMon :: Key -> Char -> World -> World
fireMon dir obj world = fst $ fireFirst dir $
	changeStore (store world ++ [obj]) world
	
