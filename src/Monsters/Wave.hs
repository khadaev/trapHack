module Monsters.Wave where

import Data.Const
import Data.Monster
import Data.Define
import Utils.Monsters
import Monsters.Monsters
import Monsters.MonsterList
import Monsters.Forgotten
import Monsters.AI
import IO.Texts

import System.Random (StdGen, randomR)
import qualified Data.Map as M
import Data.Functor ((<$>))

-- | get monster id from a generator
idFromGen :: MonsterGen -> Int
idFromGen mgen = idM $ fst $ mgen $ putWE "nameFromGen"

-- | add wave by given function
addWaveBy :: ([MonsterGen] -> (Units, StdGen) -> (Units, StdGen)) 
	-> Int -> (Units, StdGen) -> (Units, StdGen)
addWaveBy fun n (uns, g) = 
	if null ms
	then addWave n (uns, g')
	else fun ms (uns, g')
	where
		(ms, g') = genWave n g

addWave, addWaveFull :: Int -> (Units, StdGen) -> (Units, StdGen)
-- | add monsters near to you
addWave = addWaveBy addMonsters
-- | add monsters to random cells
addWaveFull = addWaveBy addMonstersFull

-- | calculate danger level of the world 
levelW :: World -> Int
levelW w = M.foldr (+) 0 $ (levelM . idM) <$> M.filter isSoldier 
	(M.filterWithKey (\(x, y) _ -> abs (x - xPlayer) <= xSight 
	&& abs (y - yPlayer) <= ySight) $ units w) where
	[((xPlayer, yPlayer), _)] = filter (\(_,m) -> name m == "You") 
		$ M.toList $ units w

-- | generate one wave
genWave :: Int -> StdGen -> ([MonsterGen], StdGen)
genWave n g
	| n <= 0 = ([], g)
	| d > n = (oldWave, g'')
	| otherwise = (genM : oldWave, g'') where
	ind :: Int
	(ind, g') = randomR (0, length gens - 1) g
	gens = replicate 4 getTree ++ 
		[getHomunculus, getBeetle, getBat, getHunter, getIvy,
		getAccelerator, getTroll, getWorm, getFloatingEye, getRedDragon, 
		getWhiteDragon, getGreenDragon, getForgottenBeast, getSpider, 
		getSoldier, getUmberHulk, getBot, getBee, getBush]
	genM = gens !! ind
	d = levelM $ idFromGen genM
	(oldWave, g'') = genWave (n - d) g'

-- | add new wave to a world
newWave :: World -> World
newWave w = w {units' = newUnits, stdgen = newStdGen, wave = wave w + 1} where
	(newUnits, newStdGen) = addWave (wave w) 
		$ addWaveFull (wave w) (units' w, stdgen w)
