module Utils.Changes where

import Data.Const
import Data.World
import Data.Monster
import Data.Define
import Monsters.Parts
import IO.Texts

import qualified Data.Set as S
import qualified Data.Map as M
import Data.Array
import Control.Arrow (first)
import Data.Functor ((<$>))

{- Units -}
-- | update current monster is 'list' field of a record
update :: Int -> Int -> Units -> Units
update x' y' uns = 
	if x' == xF uns && y' == yF uns
	then case M.lookup (x', y') $ list uns of
		Nothing -> putWE "update" 
		Just mon -> uns {getFirst' = mon}
	else uns

{- Monster -}
-- | delete 1 item with given index from current monster inventory
delObj :: Char -> Monster -> Monster
delObj c m = m {inv = newInv} where
	newInv = M.update maybeUpd c $ inv m
	maybeUpd (_, 1) = Nothing
	maybeUpd (o, n) = Just (o, n - 1)

-- | delete all items with given index from current monster inventory
delAllObj :: Char -> Monster -> Monster
delAllObj c m = m {inv = newInv} where
	newInv = M.delete c $ inv m

-- | decrease charge of the item with given index from current monster inventory 
decChargeByKey :: Char -> Monster -> Monster
decChargeByKey c m = m {inv = newInv} where
	newInv = M.adjust (first decCharge) c $ inv m

-- | add resistance to the current monster
addRes :: Elem -> Int -> Monster -> Monster
addRes elem' n m = m {res = changeElem pos new $ res m} where
	pos = fromEnum elem'
	new = res m !! pos + n

-- | add intrinsic to the current monster
addIntr :: Intr -> Int -> Monster -> Monster
addIntr intr' n m = m {intr = changeElem pos new $ intr m} where
	pos = fromEnum intr'
	new = intr m !! pos + n

-- | change temporary effect of the current monster
changeTemp:: Temp -> Maybe Int -> Monster -> Monster
changeTemp temp' n m = m {temp = changeElem pos n $ temp m} where
	pos = fromEnum temp'

-- | set temporary of the current monster to a maximum from current
-- and given values
setMaxTemp :: Temp -> Maybe Int -> Monster -> Monster
setMaxTemp temp' n m = changeTemp temp' (max n old) m where
	pos = fromEnum temp'
	old = temp m !! pos

{- World -}
-- | change the current mosnter
changeMon :: Monster -> World -> World
changeMon mon w = w {units' = newMons} where
	newMons = update x y $ (units' w) {list = M.insert (x, y) mon $ list $ units' w}
	x = xFirst w
	y = yFirst w

-- | move the current monster in given direction
changeMoveFirst :: Int -> Int -> World -> World
changeMoveFirst x y w = w {units' = newMons} where
	newMons = (units' w) {
		xF = x,
		yF = y,
		list = M.insert (x, y) mon $ M.delete (xFirst w, yFirst w) $ units w
	}
	mon = getFirst w

-- | add list of messages and colors to the world messages
addMessages :: [(String, Int)] -> World -> World
addMessages s w = w {message = message w ++ s}
-- | add one message with color to the world messages
addMessage :: (String, Int) -> World -> World
addMessage ("", _) = id
addMessage s = addMessages [s]

-- | clear world message with given screen width
clearMessage :: Int -> World -> World
clearMessage width w = w {message = 
	dropAccum (message w) maxLen} where
	maxLen = width * (shiftDown - 1) - 2
	dropAccum :: [([a], b)] -> Int -> [([a], b)]
	dropAccum [] _ = []
	dropAccum arg@((x, _):xs) n = 
		if length x <= n
		then dropAccum xs $ n - length x - 1
		else arg

-- | change position of given char when you pick ore drop many items
changeChar :: Char -> World -> World
changeChar c w = w {chars = newPick} where
	sym = c
	newPick =
		if S.member sym $ chars w
		then S.delete sym $ chars w
		else S.insert sym $ chars w

-- | add item on the ground to the world
addItem :: (Int, Int, Object, Int) -> World -> World
addItem i w = w {items = items'} where
	items' = addItem' i $ items w

-- | change one cell of the map with given coords
changeMap :: Int -> Int -> Cell -> World -> World
changeMap x y cell w = w {worldmap = worldmap'} where
	worldmap' = worldmap w // [((x, y), cell)]

-- | change only terrain with given coords
changeTerr :: Int -> Int -> Terrain -> World -> World
changeTerr x y terr w = changeMap x y Cell {terrain = terr,
	height = height $ worldmap w ! (x, y)} w

-- | spawn monster with given generator and coordinates
spawnMon :: MonsterGen -> Int -> Int -> World -> World
spawnMon mgen x y w = w {units' = (units' w) {list = M.insert (x, y)
	(newMon {time = time (getFirst w) + effectiveSlowness newMon})
		$ units w}, stdgen = g} where
	(newMon, g) = mgen $ stdgen w

-- | paralyse monster in given direction from the current monster
paralyse :: Int -> Int -> World -> World
paralyse dx dy w = w {units' = newMons} where
	xNow = xFirst w
	yNow = yFirst w
	x = xNow + dx
	y = yNow + dy
	ch (x', y') mon = 
		if x == x' && y == y'
		then mon {time = time mon + effectiveSlowness mon * 3 `div` 2}
		else mon
	newMons = mapU ch $ units' w

changeShiftOn, changeSlotOn :: Int -> World -> World
-- | increase 'shift' by modulo
changeShiftOn n w = w {shift = mod (shift w + n) $ length $ parts $ getFirst w}
-- | increase 'slot' by modulo
changeSlotOn n w = w {slot = toEnum $ flip mod sLOTS $ (+n) $ fromEnum $ slot w}

{- Object -}

-- | decrease charge of object
decCharge :: Object -> Object
decCharge obj = obj {charge = charge obj - 1}

-- | invrease enchantment of object
enchant :: Int -> Object -> Object
enchant n obj = obj {enchantment = enchantment obj + n} 

{- Other -}

-- | change one element of a list with given index
changeElem :: Int -> a -> [a] -> [a]
changeElem _ _ [] = putWE "changeElem"
changeElem x t (a:as)
	| x == 0 = t : as
	| x > 0 = a : changeElem (x - 1) t as
	| otherwise = putWE "changeElem"

-- | add item to list of items on the ground
addItem' :: (Int, Int, Object, Int) -> [(Int, Int, Object, Int)] -> [(Int, Int, Object, Int)]
addItem' i@(x, y, obj, n) list' = 
	if null this
	then i : list'
	else change <$> list'
	where
		change i'@(x', y', obj', n') = 
			if x == x' && y == y' && obj == obj'
			then (x', y', obj', n + n')
			else i'
		this = filter (\(x', y', obj', _) -> x == x' && y == y' && obj == obj') list'
