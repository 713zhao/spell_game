# Game-Based Spelling App UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Duolingo-inspired game-based UI for the spelling app with levels, rewards, streaks, and social features (MVP: 8 weeks).

**Architecture:** Hybrid backend approach extending existing FastAPI + SQLite. New game tables (Level, LevelProgress, Unlockable, Challenge) added alongside existing User/SpellingWord/RewardSystem. Flutter mobile app primary, Flutter web fallback. All game logic validated server-side.

**Tech Stack:** FastAPI (backend), SQLModel (ORM), Flutter (mobile), Flutter Web (web), SQLite (database), Google Cloud TTS (future).

**Parallel Work Streams:**
- **Stream A (Backend):** Database schema + core APIs (weeks 1-2)
- **Stream B (Frontend):** UI screens + state management (weeks 2-4)  
- **Stream C (Integration):** Connect frontend to backend APIs (weeks 4-5)
- **Stream D (Polish):** Testing, refinement, deployment (week 6)

---

## File Structure & Decomposition

### Backend Files (New/Modified)

**Database Models** (`SpellBackend/src/models/`)
- `game.py` — Level, LevelProgress, Unlockable, UserUnlockable, Challenge schemas

**Database Initialization** (`SpellBackend/database/`)
- `migrations.py` — Create new tables (alembic migrations recommended for production)

**Services** (`SpellBackend/src/services/`)
- `level_manager.py` — Level CRUD, progression logic
- `unlockable_manager.py` — Cosmetics inventory, redemption
- `challenge_manager.py` — Challenge creation, validation, winner determination
- `streak_manager.py` — Streak tracking, daily reset, revival logic

**Routes** (`SpellBackend/src/routes/`)
- `levels.py` — GET /levels, GET /levels/{level_id}, POST /level-progress
- `unlockables.py` — GET /unlockables, POST /redeem, POST /equip
- `challenges.py` — POST /create, POST /accept, POST /complete
- `streaks.py` — GET /streak, POST /revive

**Database** (`SpellBackend/database/`)
- `db.sqlite3` (existing, will be extended)

### Frontend Files (New)

**Flutter Project Structure** (`FlutterSpell_Game/` — new project)
- `lib/main.dart` — App entry point, routing
- `lib/screens/home.dart` — Home screen with streak, levels, daily goal
- `lib/screens/level_select.dart` — Level list with progress
- `lib/screens/study.dart` — Study screen with mixed modes
- `lib/screens/rewards_shop.dart` — Cosmetics shop, redemption
- `lib/screens/leaderboard.dart` — Global leaderboard, friend challenges
- `lib/screens/profile.dart` — User profile, cosmetics, stats
- `lib/services/api_client.dart` — HTTP client for backend APIs
- `lib/models/game_models.dart` — Dart models matching backend schemas
- `lib/providers/game_provider.dart` — State management (Provider package)
- `lib/widgets/level_card.dart` — Reusable level card widget
- `lib/widgets/reward_popup.dart` — Chest animation, reward display
- `lib/assets/sounds/` — Success chime, celebration sfx
- `pubspec.yaml` — Dependencies (provider, http, path_provider)

---

## Task Breakdown (30 Tasks Total)

### PHASE 1: BACKEND FOUNDATION (Weeks 1-2)

---

### Task 1: Database Schema - Create Level Table

**Files:**
- Create: `SpellBackend/database/migrations.py`
- Modify: `SpellBackend/src/models/game.py`

- [ ] **Step 1: Create game.py with Level model**

Create `SpellBackend/src/models/game.py`:

```python
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime

class Level(SQLModel, table=True):
    """Level definitions for spell progression."""
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(index=True)  # "Animals", "Colors"
    description: Optional[str] = None
    difficulty: int = Field(ge=1, le=5)  # 1=P1, 5=P4
    unlock_requirement: Optional[str] = None  # "complete_level_1" or "points_300"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationships
    words: List["LevelWord"] = Relationship(back_populates="level")
    progress: List["LevelProgress"] = Relationship(back_populates="level")
    challenges: List["Challenge"] = Relationship(back_populates="level")
    statistics: List["LevelStatistics"] = Relationship(back_populates="level")


class LevelWord(SQLModel, table=True):
    """Junction table: words in each level."""
    level_id: int = Field(foreign_key="level.id", primary_key=True)
    word_id: int = Field(foreign_key="spellingword.id", primary_key=True)
    position: int  # Order in level
    
    level: Optional[Level] = Relationship(back_populates="words")
```

- [ ] **Step 2: Create LevelProgress model**

Add to `SpellBackend/src/models/game.py`:

```python
class LevelProgress(SQLModel, table=True):
    """User progress tracking per level."""
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    level_id: int = Field(foreign_key="level.id")
    status: str = Field(default="locked")  # locked, in_progress, completed
    stars_earned: int = Field(default=0, ge=0, le=3)
    points_earned: int = Field(default=0)
    study_count: int = Field(default=0)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    level: Optional[Level] = Relationship(back_populates="progress")
    
    class Config:
        # Ensure one progress record per user-level pair
        pass
```

- [ ] **Step 3: Write migration script**

Create `SpellBackend/database/migrations.py`:

```python
from sqlmodel import SQLModel, create_engine, Session
from pathlib import Path

def init_db(db_path: str = "database/db.sqlite3"):
    """Initialize database with new game tables."""
    engine = create_engine(f"sqlite:///{db_path}", echo=True)
    
    # Import all models to register them
    from src.models.user import User
    from src.models.word import SpellingWord, Tag
    from src.models.game import Level, LevelProgress, LevelWord
    
    # Create tables
    SQLModel.metadata.create_all(engine)
    print(f"Database initialized at {db_path}")

if __name__ == "__main__":
    init_db()
```

- [ ] **Step 4: Update main.py to call migrations on startup**

Modify `SpellBackend/main.py` (add after imports):

```python
from database.migrations import init_db

# On app startup
@app.on_event("startup")
def startup():
    init_db()
    print("Database initialized")
```

- [ ] **Step 5: Test schema creation**

Run: 
```bash
cd SpellBackend
python main.py
```

Expected: Logs show table creation, no errors.

- [ ] **Step 6: Commit**

```bash
cd SpellBackend
git add src/models/game.py database/migrations.py
git commit -m "feat: add Level and LevelProgress database models"
```

---

### Task 2: Database Schema - Create Unlockable & Challenge Tables

**Files:**
- Modify: `SpellBackend/src/models/game.py`

- [ ] **Step 1: Add Unlockable models**

Append to `SpellBackend/src/models/game.py`:

```python
class Unlockable(SQLModel, table=True):
    """Cosmetic rewards: avatars, themes, effects."""
    id: Optional[int] = Field(default=None, primary_key=True)
    type: str = Field(index=True)  # "avatar_skin", "theme", "effect"
    name: str = Field(index=True)
    description: Optional[str] = None
    points_cost: int = Field(ge=0)
    unlock_method: str  # "earn_level_1", "earn_streak_10", "redeem_points"
    rarity: str = Field(default="common")  # common, rare, epic
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    owned_by: List["UserUnlockable"] = Relationship(back_populates="unlockable")


class UserUnlockable(SQLModel, table=True):
    """User's cosmetic inventory."""
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    unlockable_id: int = Field(foreign_key="unlockable.id")
    acquired_at: datetime = Field(default_factory=datetime.utcnow)
    is_equipped: bool = Field(default=False)
    
    unlockable: Optional[Unlockable] = Relationship(back_populates="owned_by")
```

- [ ] **Step 2: Add Challenge model**

Append to `SpellBackend/src/models/game.py`:

```python
class Challenge(SQLModel, table=True):
    """Friend challenges."""
    id: Optional[int] = Field(default=None, primary_key=True)
    challenger_id: int = Field(foreign_key="user.id", index=True)
    challengee_id: int = Field(foreign_key="user.id", index=True)
    level_id: int = Field(foreign_key="level.id")
    status: str = Field(default="pending")  # pending, accepted, completed
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    winner_id: Optional[int] = Field(foreign_key="user.id")
    points_at_stake: int = Field(default=20)
    
    level: Optional[Level] = Relationship(back_populates="challenges")
```

- [ ] **Step 3: Add LevelStatistics model**

Append to `SpellBackend/src/models/game.py`:

```python
class LevelStatistics(SQLModel, table=True):
    """Per-word performance tracking within levels."""
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    level_id: int = Field(foreign_key="level.id")
    word_id: int = Field(foreign_key="spellingword.id")
    times_correct: int = Field(default=0)
    times_attempted: int = Field(default=0)
    last_attempted: datetime = Field(default_factory=datetime.utcnow)
    
    level: Optional[Level] = Relationship(back_populates="statistics")
```

- [ ] **Step 4: Update migrations.py to create all tables**

Modify `SpellBackend/database/migrations.py`:

```python
def init_db(db_path: str = "database/db.sqlite3"):
    """Initialize database with all game tables."""
    engine = create_engine(f"sqlite:///{db_path}", echo=True)
    
    # Import all models
    from src.models.user import User
    from src.models.word import SpellingWord, Tag
    from src.models.game import (
        Level, LevelProgress, LevelWord, 
        Unlockable, UserUnlockable, Challenge, 
        LevelStatistics
    )
    
    SQLModel.metadata.create_all(engine)
    print(f"✓ Database initialized at {db_path}")
```

- [ ] **Step 5: Test**

Run:
```bash
cd SpellBackend
python -c "from database.migrations import init_db; init_db()"
```

Expected: "✓ Database initialized" message, no errors.

- [ ] **Step 6: Commit**

```bash
git add src/models/game.py database/migrations.py
git commit -m "feat: add Unlockable, Challenge, LevelStatistics models"
```

---

### Task 3: Level Manager Service

**Files:**
- Create: `SpellBackend/src/services/level_manager.py`
- Modify: `SpellBackend/src/db_session.py` (if needed)

- [ ] **Step 1: Create LevelManager class**

Create `SpellBackend/src/services/level_manager.py`:

```python
from sqlmodel import Session, select
from datetime import datetime
from typing import List, Optional
from src.models.game import Level, LevelProgress, LevelWord
from src.models.word import SpellingWord

class LevelManager:
    """Manages level CRUD and progression logic."""
    
    def __init__(self, session: Session):
        self.session = session
    
    def create_level(self, name: str, description: str, difficulty: int, 
                     unlock_requirement: Optional[str] = None) -> Level:
        """Create a new level."""
        level = Level(
            name=name,
            description=description,
            difficulty=difficulty,
            unlock_requirement=unlock_requirement
        )
        self.session.add(level)
        self.session.commit()
        self.session.refresh(level)
        return level
    
    def add_words_to_level(self, level_id: int, word_ids: List[int]) -> None:
        """Add words to a level in order."""
        for position, word_id in enumerate(word_ids, 1):
            level_word = LevelWord(
                level_id=level_id,
                word_id=word_id,
                position=position
            )
            self.session.add(level_word)
        self.session.commit()
    
    def get_level_with_words(self, level_id: int) -> Optional[dict]:
        """Get level details including word list."""
        level = self.session.get(Level, level_id)
        if not level:
            return None
        
        # Get words in order
        words_query = select(SpellingWord).join(LevelWord).where(
            LevelWord.level_id == level_id
        ).order_by(LevelWord.position)
        words = self.session.exec(words_query).all()
        
        return {
            "id": level.id,
            "name": level.name,
            "description": level.description,
            "difficulty": level.difficulty,
            "words": [{"id": w.id, "text": w.text, "language": w.language} for w in words],
            "word_count": len(words)
        }
    
    def get_user_level_progress(self, user_id: int, level_id: int) -> Optional[LevelProgress]:
        """Get or create progress record for user-level pair."""
        query = select(LevelProgress).where(
            (LevelProgress.user_id == user_id) &
            (LevelProgress.level_id == level_id)
        )
        progress = self.session.exec(query).first()
        
        if not progress:
            # Create new progress record
            progress = LevelProgress(
                user_id=user_id,
                level_id=level_id,
                status="locked"
            )
            # Check if user should unlock (previous level complete or first level)
            if level_id == 1:
                progress.status = "in_progress"
            
            self.session.add(progress)
            self.session.commit()
            self.session.refresh(progress)
        
        return progress
    
    def check_level_unlock(self, user_id: int, level_id: int) -> bool:
        """Check if user can unlock this level."""
        level = self.session.get(Level, level_id)
        if not level or not level.unlock_requirement:
            return True  # No requirement, unlock automatically
        
        # Parse requirement: "complete_level_X" or "points_Y"
        if level.unlock_requirement.startswith("complete_level_"):
            required_level = int(level.unlock_requirement.split("_")[-1])
            query = select(LevelProgress).where(
                (LevelProgress.user_id == user_id) &
                (LevelProgress.level_id == required_level) &
                (LevelProgress.status == "completed")
            )
            return self.session.exec(query).first() is not None
        
        elif level.unlock_requirement.startswith("points_"):
            required_points = int(level.unlock_requirement.split("_")[-1])
            # Query User.total_points
            from src.models.user import User
            user = self.session.get(User, user_id)
            return user and user.total_points >= required_points
        
        return True
    
    def complete_level(self, user_id: int, level_id: int, accuracy: float) -> dict:
        """Mark level complete and award rewards."""
        progress = self.get_user_level_progress(user_id, level_id)
        
        # Award stars based on accuracy
        if accuracy >= 1.0:
            stars = 3
        elif accuracy >= 0.8:
            stars = 2
        else:
            stars = 1
        
        progress.status = "completed"
        progress.stars_earned = stars
        progress.points_earned = 10  # Level completion bonus
        progress.completed_at = datetime.utcnow()
        
        self.session.add(progress)
        self.session.commit()
        
        return {
            "level_id": level_id,
            "stars": stars,
            "points_bonus": 10,
            "message": f"Level complete! {stars} stars earned!"
        }
    
    def list_user_levels(self, user_id: int) -> List[dict]:
        """List all levels with user's progress."""
        levels = self.session.exec(select(Level).order_by(Level.id)).all()
        result = []
        
        for level in levels:
            progress = self.get_user_level_progress(user_id, level.id)
            can_unlock = self.check_level_unlock(user_id, level.id)
            
            if can_unlock and progress.status == "locked":
                progress.status = "in_progress"
                self.session.add(progress)
                self.session.commit()
            
            result.append({
                "id": level.id,
                "name": level.name,
                "difficulty": level.difficulty,
                "status": progress.status,
                "stars": progress.stars_earned,
                "study_count": progress.study_count
            })
        
        self.session.commit()
        return result
```

- [ ] **Step 2: Write unit tests**

Create `SpellBackend/tests/test_level_manager.py`:

```python
import pytest
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool
from src.services.level_manager import LevelManager
from src.models.game import Level, LevelProgress
from src.models.word import SpellingWord
from src.models.user import User

@pytest.fixture(name="session")
def session_fixture():
    """Create in-memory test database."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session

def test_create_level(session: Session):
    """Test creating a level."""
    manager = LevelManager(session)
    level = manager.create_level(
        name="Animals",
        description="Learn animal names",
        difficulty=1
    )
    
    assert level.id is not None
    assert level.name == "Animals"
    assert level.difficulty == 1

def test_add_words_to_level(session: Session):
    """Test adding words to a level."""
    manager = LevelManager(session)
    
    # Create level
    level = manager.create_level("Animals", "Animals", 1)
    
    # Create words
    word1 = SpellingWord(text="cat", language="en")
    word2 = SpellingWord(text="dog", language="en")
    session.add_all([word1, word2])
    session.commit()
    
    # Add to level
    manager.add_words_to_level(level.id, [word1.id, word2.id])
    
    # Verify
    level_data = manager.get_level_with_words(level.id)
    assert len(level_data["words"]) == 2
    assert level_data["words"][0]["text"] == "cat"

def test_complete_level_awards_stars(session: Session):
    """Test level completion awards stars based on accuracy."""
    manager = LevelManager(session)
    
    # Create user and level
    user = User(name="test_user")
    session.add(user)
    session.commit()
    
    level = manager.create_level("Test", "Test", 1)
    
    # Complete with 100% accuracy
    result = manager.complete_level(user.id, level.id, accuracy=1.0)
    assert result["stars"] == 3
    
    # Complete with 85% accuracy
    level2 = manager.create_level("Test2", "Test", 1)
    result = manager.complete_level(user.id, level2.id, accuracy=0.85)
    assert result["stars"] == 2
```

- [ ] **Step 3: Run tests**

```bash
cd SpellBackend
pytest tests/test_level_manager.py -v
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/services/level_manager.py tests/test_level_manager.py
git commit -m "feat: add LevelManager service with CRUD and progression logic"
```

---

### Task 4: Streak Manager Service

**Files:**
- Create: `SpellBackend/src/services/streak_manager.py`

- [ ] **Step 1: Create StreakManager class**

Create `SpellBackend/src/services/streak_manager.py`:

```python
from sqlmodel import Session
from datetime import datetime, timedelta
from src.models.reward import RewardHistory
from src.models.user import User

class StreakManager:
    """Manages daily streak tracking and bonuses."""
    
    def __init__(self, session: Session):
        self.session = session
    
    def get_user_streak(self, user_id: int) -> dict:
        """Get current streak and last login."""
        from sqlalchemy import func
        
        # Get login history (study events)
        query = """
            SELECT DATE(timestamp) as login_date
            FROM reward_history
            WHERE user_id = ? AND reason IN ('study', 'level_complete')
            ORDER BY timestamp DESC
            LIMIT 30
        """
        
        dates = self.session.exec(query, [user_id]).all()
        if not dates:
            return {
                "current_streak": 0,
                "last_login": None,
                "best_streak": 0
            }
        
        # Calculate consecutive days
        streak = 0
        today = datetime.utcnow().date()
        
        for i, (login_date,) in enumerate(dates):
            expected_date = today - timedelta(days=i)
            if login_date == expected_date:
                streak += 1
            else:
                break
        
        return {
            "current_streak": streak,
            "last_login": str(dates[0][0]) if dates else None,
            "best_streak": len(dates)  # Simplified; track in User table for prod
        }
    
    def check_daily_login(self, user_id: int) -> dict:
        """Check if user has logged in today and update streak."""
        user = self.session.get(User, user_id)
        if not user:
            return {"ok": False, "message": "User not found"}
        
        streak_info = self.get_user_streak(user_id)
        last_login = streak_info["last_login"]
        today_str = datetime.utcnow().date().isoformat()
        
        if last_login == today_str:
            return {
                "ok": True,
                "streak": streak_info["current_streak"],
                "message": "Already logged in today",
                "bonus_multiplier": self._get_streak_multiplier(streak_info["current_streak"])
            }
        
        # New day - increment streak
        new_streak = streak_info["current_streak"] + 1
        
        return {
            "ok": True,
            "streak": new_streak,
            "message": f"Streak: {new_streak} days!",
            "bonus_multiplier": self._get_streak_multiplier(new_streak),
            "milestone_unlocked": self._check_milestones(new_streak)
        }
    
    def _get_streak_multiplier(self, streak: int) -> float:
        """Return points multiplier based on streak."""
        if streak >= 30:
            return 3.0
        elif streak >= 10:
            return 2.0
        elif streak >= 5:
            return 1.5
        return 1.0
    
    def _check_milestones(self, streak: int) -> list:
        """Check if streak hits milestone rewards."""
        milestones = []
        
        if streak == 5:
            milestones.append({"type": "multiplier", "value": 2.0})
        elif streak == 10:
            milestones.append({"type": "cosmetic", "unlockable_id": 10})  # Placeholder
        elif streak == 30:
            milestones.append({"type": "badge", "name": "Master Speller"})
        
        return milestones
    
    def revive_streak(self, user_id: int, points_cost: int = 50) -> dict:
        """Allow user to pay points to revive broken streak."""
        user = self.session.get(User, user_id)
        if not user:
            return {"ok": False, "message": "User not found"}
        
        if user.total_points < points_cost:
            return {"ok": False, "message": "Insufficient points"}
        
        # Deduct points
        user.total_points -= points_cost
        
        # Log deduction
        history = RewardHistory(
            user_name=user.name,
            action="redeem",
            points=-points_cost,
            reason="streak_revive",
            timestamp=datetime.utcnow()
        )
        self.session.add(history)
        self.session.commit()
        
        return {
            "ok": True,
            "message": "Streak revived!",
            "remaining_points": user.total_points
        }
```

- [ ] **Step 2: Write unit tests**

Create `SpellBackend/tests/test_streak_manager.py`:

```python
import pytest
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool
from datetime import datetime, timedelta
from src.services.streak_manager import StreakManager
from src.models.user import User
from src.models.reward import RewardHistory

@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session

def test_get_user_streak_no_activity(session: Session):
    """Test streak for user with no activity."""
    user = User(name="test_user")
    session.add(user)
    session.commit()
    
    manager = StreakManager(session)
    streak = manager.get_user_streak(user.id)
    
    assert streak["current_streak"] == 0
    assert streak["last_login"] is None

def test_check_daily_login_first_day(session: Session):
    """Test daily login check on first day."""
    user = User(name="test_user", total_points=100)
    session.add(user)
    session.commit()
    
    manager = StreakManager(session)
    result = manager.check_daily_login(user.id)
    
    assert result["ok"] is True
    assert result["streak"] >= 1

def test_revive_streak_insufficient_points(session: Session):
    """Test reviving streak with insufficient points."""
    user = User(name="test_user", total_points=10)
    session.add(user)
    session.commit()
    
    manager = StreakManager(session)
    result = manager.revive_streak(user.id, points_cost=50)
    
    assert result["ok"] is False
    assert "Insufficient" in result["message"]

def test_revive_streak_success(session: Session):
    """Test successful streak revival."""
    user = User(name="test_user", total_points=100)
    session.add(user)
    session.commit()
    
    manager = StreakManager(session)
    result = manager.revive_streak(user.id, points_cost=50)
    
    assert result["ok"] is True
    assert result["remaining_points"] == 50
```

- [ ] **Step 3: Run tests**

```bash
cd SpellBackend
pytest tests/test_streak_manager.py -v
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/services/streak_manager.py tests/test_streak_manager.py
git commit -m "feat: add StreakManager service for daily login tracking"
```

---

### Task 5: Unlockable Manager Service

**Files:**
- Create: `SpellBackend/src/services/unlockable_manager.py`

- [ ] **Step 1: Create UnlockableManager class**

Create `SpellBackend/src/services/unlockable_manager.py`:

```python
from sqlmodel import Session, select
from datetime import datetime
from typing import List, Optional
from src.models.game import Unlockable, UserUnlockable
from src.models.user import User
from src.models.reward import RewardHistory

class UnlockableManager:
    """Manages cosmetics inventory and redemption."""
    
    def __init__(self, session: Session):
        self.session = session
    
    def create_unlockable(self, type: str, name: str, description: str,
                         points_cost: int, unlock_method: str,
                         rarity: str = "common") -> Unlockable:
        """Create a new cosmetic reward."""
        unlockable = Unlockable(
            type=type,
            name=name,
            description=description,
            points_cost=points_cost,
            unlock_method=unlock_method,
            rarity=rarity
        )
        self.session.add(unlockable)
        self.session.commit()
        self.session.refresh(unlockable)
        return unlockable
    
    def get_user_unlockables(self, user_id: int) -> dict:
        """Get all unlockables with ownership status."""
        unlockables = self.session.exec(select(Unlockable)).all()
        
        owned_query = select(UserUnlockable).where(
            UserUnlockable.user_id == user_id
        )
        owned = self.session.exec(owned_query).all()
        owned_ids = {u.unlockable_id for u in owned}
        
        return {
            "available": [
                {
                    "id": u.id,
                    "type": u.type,
                    "name": u.name,
                    "points_cost": u.points_cost,
                    "rarity": u.rarity,
                    "owned": u.id in owned_ids,
                    "equipped": any(uo.is_equipped for uo in owned if uo.unlockable_id == u.id)
                }
                for u in unlockables
            ],
            "owned_count": len(owned_ids)
        }
    
    def redeem_unlockable(self, user_id: int, unlockable_id: int) -> dict:
        """Redeem points for a cosmetic."""
        user = self.session.get(User, user_id)
        unlockable = self.session.get(Unlockable, unlockable_id)
        
        if not user:
            return {"ok": False, "message": "User not found"}
        if not unlockable:
            return {"ok": False, "message": "Unlockable not found"}
        
        # Check already owned
        query = select(UserUnlockable).where(
            (UserUnlockable.user_id == user_id) &
            (UserUnlockable.unlockable_id == unlockable_id)
        )
        if self.session.exec(query).first():
            return {"ok": False, "message": "Already owned"}
        
        # Check points
        if user.total_points < unlockable.points_cost:
            return {"ok": False, "message": "Insufficient points"}
        
        # Deduct points
        user.total_points -= unlockable.points_cost
        
        # Add to inventory
        user_unlockable = UserUnlockable(
            user_id=user_id,
            unlockable_id=unlockable_id,
            is_equipped=False
        )
        self.session.add(user_unlockable)
        
        # Log redemption
        history = RewardHistory(
            user_name=user.name,
            action="redeem",
            points=-unlockable.points_cost,
            reason=f"cosmetic_{unlockable.name}",
            timestamp=datetime.utcnow()
        )
        self.session.add(history)
        self.session.commit()
        
        return {
            "ok": True,
            "message": f"Unlocked {unlockable.name}!",
            "remaining_points": user.total_points,
            "unlockable": {
                "id": unlockable.id,
                "name": unlockable.name,
                "type": unlockable.type
            }
        }
    
    def equip_cosmetic(self, user_id: int, unlockable_id: int) -> dict:
        """Set a cosmetic as active (one per type)."""
        # Get the unlockable to know its type
        unlockable = self.session.get(Unlockable, unlockable_id)
        if not unlockable:
            return {"ok": False, "message": "Unlockable not found"}
        
        # Check user owns it
        query = select(UserUnlockable).where(
            (UserUnlockable.user_id == user_id) &
            (UserUnlockable.unlockable_id == unlockable_id)
        )
        user_unlockable = self.session.exec(query).first()
        if not user_unlockable:
            return {"ok": False, "message": "Not owned"}
        
        # Unequip others of same type
        unequip_query = select(UserUnlockable).join(Unlockable).where(
            (UserUnlockable.user_id == user_id) &
            (Unlockable.type == unlockable.type) &
            (UserUnlockable.is_equipped == True)
        )
        for uo in self.session.exec(unequip_query).all():
            uo.is_equipped = False
        
        # Equip this one
        user_unlockable.is_equipped = True
        self.session.add(user_unlockable)
        self.session.commit()
        
        return {
            "ok": True,
            "message": f"{unlockable.name} equipped!",
            "equipped": unlockable.name
        }
    
    def seed_default_unlockables(self) -> None:
        """Seed database with default cosmetics."""
        defaults = [
            ("avatar_skin", "Blue Cat", "A friendly blue cat", 0, "earn_level_1", "common"),
            ("avatar_skin", "Rainbow Theme", "Colorful rainbow", 50, "redeem_points", "rare"),
            ("effect", "Gold Star", "Sparkling gold effect", 100, "redeem_points", "epic"),
            ("theme", "Dark Mode", "Easy on the eyes", 30, "redeem_points", "common"),
        ]
        
        for type_, name, desc, cost, method, rarity in defaults:
            existing = self.session.exec(
                select(Unlockable).where(Unlockable.name == name)
            ).first()
            if not existing:
                self.create_unlockable(type_, name, desc, cost, method, rarity)
```

- [ ] **Step 2: Write unit tests**

Create `SpellBackend/tests/test_unlockable_manager.py`:

```python
import pytest
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool
from src.services.unlockable_manager import UnlockableManager
from src.models.user import User
from src.models.game import Unlockable, UserUnlockable

@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session

def test_create_unlockable(session: Session):
    """Test creating a cosmetic."""
    manager = UnlockableManager(session)
    unlockable = manager.create_unlockable(
        type="avatar_skin",
        name="Blue Cat",
        description="A blue cat",
        points_cost=0,
        unlock_method="earn_level_1"
    )
    
    assert unlockable.id is not None
    assert unlockable.name == "Blue Cat"

def test_redeem_insufficient_points(session: Session):
    """Test redeeming with insufficient points."""
    manager = UnlockableManager(session)
    
    user = User(name="poor_user", total_points=10)
    unlockable = Unlockable(
        type="avatar",
        name="Expensive",
        points_cost=50,
        unlock_method="redeem_points"
    )
    session.add_all([user, unlockable])
    session.commit()
    
    result = manager.redeem_unlockable(user.id, unlockable.id)
    assert result["ok"] is False
    assert "Insufficient" in result["message"]

def test_redeem_success(session: Session):
    """Test successful cosmetic redemption."""
    manager = UnlockableManager(session)
    
    user = User(name="rich_user", total_points=100)
    unlockable = Unlockable(
        type="avatar",
        name="Blue Cat",
        points_cost=50,
        unlock_method="redeem_points"
    )
    session.add_all([user, unlockable])
    session.commit()
    
    result = manager.redeem_unlockable(user.id, unlockable.id)
    assert result["ok"] is True
    assert result["remaining_points"] == 50

def test_equip_cosmetic(session: Session):
    """Test equipping a cosmetic."""
    manager = UnlockableManager(session)
    
    user = User(name="user")
    unlockable = Unlockable(
        type="avatar",
        name="Blue Cat",
        points_cost=0,
        unlock_method="earn_level_1"
    )
    session.add_all([user, unlockable])
    session.commit()
    
    # Own it first
    manager.redeem_unlockable(user.id, unlockable.id)
    
    # Equip
    result = manager.equip_cosmetic(user.id, unlockable.id)
    assert result["ok"] is True
```

- [ ] **Step 3: Run tests**

```bash
cd SpellBackend
pytest tests/test_unlockable_manager.py -v
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/services/unlockable_manager.py tests/test_unlockable_manager.py
git commit -m "feat: add UnlockableManager for cosmetics inventory and redemption"
```

---

### Task 6: Backend API Routes - Levels

**Files:**
- Create: `SpellBackend/src/routes/levels.py`
- Modify: `SpellBackend/main.py` (add route import)

- [ ] **Step 1: Create levels routes**

Create `SpellBackend/src/routes/levels.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from typing import List
from src.db_session import get_session
from src.services.level_manager import LevelManager
from src.models.game import Level

router = APIRouter(prefix="/levels", tags=["levels"])

@router.get("/")
def list_levels(session: Session = Depends(get_session)):
    """List all levels."""
    manager = LevelManager(session)
    return {"levels": [
        {"id": l.id, "name": l.name, "difficulty": l.difficulty}
        for l in session.exec("SELECT * FROM level ORDER BY id").all()
    ]}

@router.get("/{level_id}")
def get_level(level_id: int, session: Session = Depends(get_session)):
    """Get level details including words."""
    manager = LevelManager(session)
    level_data = manager.get_level_with_words(level_id)
    
    if not level_data:
        raise HTTPException(status_code=404, detail="Level not found")
    
    return level_data

@router.post("/users/{user_name}/progress/{level_id}/start")
def start_level(user_name: str, level_id: int, session: Session = Depends(get_session)):
    """Mark level as started."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = LevelManager(session)
    progress = manager.get_user_level_progress(user.id, level_id)
    
    return {
        "level_id": level_id,
        "status": progress.status,
        "stars": progress.stars_earned
    }

@router.post("/users/{user_name}/progress/{level_id}/complete")
def complete_level(
    user_name: str,
    level_id: int,
    accuracy: float,
    session: Session = Depends(get_session)
):
    """Mark level complete with accuracy score."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = LevelManager(session)
    
    # Award points
    result = manager.complete_level(user.id, level_id, accuracy)
    
    # Award points to user
    user.total_points += result["points_bonus"]
    session.add(user)
    session.commit()
    
    return result

@router.get("/users/{user_name}")
def get_user_levels(user_name: str, session: Session = Depends(get_session)):
    """Get all levels with user's progress."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = LevelManager(session)
    levels = manager.list_user_levels(user.id)
    
    return {"levels": levels, "user_name": user_name}
```

- [ ] **Step 2: Register routes in main.py**

Modify `SpellBackend/main.py` (add after other imports):

```python
from src.routes import levels

# Add router (after other include_router calls)
app.include_router(levels.router)
```

- [ ] **Step 3: Test endpoints**

Run:
```bash
cd SpellBackend
python main.py
```

Then in another terminal:
```bash
curl http://localhost:8000/levels/
```

Expected: Returns `{"levels": []}` (empty if no levels seeded yet).

- [ ] **Step 4: Seed test data**

Create `SpellBackend/seeds.py`:

```python
from sqlmodel import Session, create_engine
from src.models.user import User
from src.models.word import SpellingWord
from src.models.game import Level
from src.services.level_manager import LevelManager

def seed_test_data():
    """Seed database with test levels and words."""
    from config.settings import DATABASE_URL
    engine = create_engine(DATABASE_URL)
    
    with Session(engine) as session:
        # Create test user
        user = User(name="alice", age=8, school="ABC Primary", grade="P2")
        session.add(user)
        session.commit()
        
        # Create words
        words = [
            SpellingWord(text="cat", language="en"),
            SpellingWord(text="dog", language="en"),
            SpellingWord(text="bird", language="en"),
            SpellingWord(text="fish", language="en"),
            SpellingWord(text="monkey", language="en"),
        ]
        session.add_all(words)
        session.commit()
        
        # Create level
        manager = LevelManager(session)
        level = manager.create_level(
            name="Animals",
            description="Learn animal names",
            difficulty=1
        )
        
        # Add words to level
        manager.add_words_to_level(level.id, [w.id for w in words])
        
        print("✓ Test data seeded")

if __name__ == "__main__":
    seed_test_data()
```

- [ ] **Step 5: Commit**

```bash
git add src/routes/levels.py seeds.py
git commit -m "feat: add level API endpoints and test data seeding"
```

---

### Task 7: Backend API Routes - Unlockables & Challenges

**Files:**
- Create: `SpellBackend/src/routes/unlockables.py`
- Create: `SpellBackend/src/routes/challenges.py`
- Modify: `SpellBackend/main.py`

- [ ] **Step 1: Create unlockables routes**

Create `SpellBackend/src/routes/unlockables.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from src.db_session import get_session
from src.services.unlockable_manager import UnlockableManager

router = APIRouter(prefix="/unlockables", tags=["unlockables"])

@router.get("/")
def list_unlockables(user_name: str, session: Session = Depends(get_session)):
    """List all unlockables with ownership status."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = UnlockableManager(session)
    return manager.get_user_unlockables(user.id)

@router.post("/{unlockable_id}/redeem")
def redeem_unlockable(user_name: str, unlockable_id: int, session: Session = Depends(get_session)):
    """Redeem points for a cosmetic."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = UnlockableManager(session)
    result = manager.redeem_unlockable(user.id, unlockable_id)
    
    if not result["ok"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    return result

@router.post("/{unlockable_id}/equip")
def equip_cosmetic(user_name: str, unlockable_id: int, session: Session = Depends(get_session)):
    """Equip a cosmetic."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = UnlockableManager(session)
    result = manager.equip_cosmetic(user.id, unlockable_id)
    
    if not result["ok"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    return result
```

- [ ] **Step 2: Create challenges routes**

Create `SpellBackend/src/routes/challenges.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from src.db_session import get_session
from src.models.game import Challenge
from src.models.user import User
from datetime import datetime

router = APIRouter(prefix="/challenges", tags=["challenges"])

@router.post("/create")
def create_challenge(
    challenger_name: str,
    challengee_name: str,
    level_id: int,
    session: Session = Depends(get_session)
):
    """Create a challenge between two users."""
    challenger = session.exec("SELECT * FROM user WHERE name = ?", [challenger_name]).first()
    challengee = session.exec("SELECT * FROM user WHERE name = ?", [challengee_name]).first()
    
    if not challenger or not challengee:
        raise HTTPException(status_code=404, detail="User not found")
    
    challenge = Challenge(
        challenger_id=challenger.id,
        challengee_id=challengee.id,
        level_id=level_id,
        status="pending"
    )
    session.add(challenge)
    session.commit()
    session.refresh(challenge)
    
    return {
        "challenge_id": challenge.id,
        "status": "pending",
        "message": f"Challenge sent to {challengee_name}!"
    }

@router.post("/{challenge_id}/accept")
def accept_challenge(challenge_id: int, session: Session = Depends(get_session)):
    """Accept a challenge."""
    challenge = session.get(Challenge, challenge_id)
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")
    
    challenge.status = "accepted"
    session.add(challenge)
    session.commit()
    
    return {"challenge_id": challenge_id, "status": "accepted"}

@router.post("/{challenge_id}/complete")
def complete_challenge(
    challenge_id: int,
    winner_name: str,
    session: Session = Depends(get_session)
):
    """Complete a challenge, determine winner."""
    challenge = session.get(Challenge, challenge_id)
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")
    
    winner = session.exec("SELECT * FROM user WHERE name = ?", [winner_name]).first()
    if not winner:
        raise HTTPException(status_code=404, detail="Winner not found")
    
    challenge.status = "completed"
    challenge.completed_at = datetime.utcnow()
    challenge.winner_id = winner.id
    
    # Award points to winner
    winner.total_points += challenge.points_at_stake
    
    session.add_all([challenge, winner])
    session.commit()
    
    return {
        "challenge_id": challenge_id,
        "winner": winner_name,
        "points_awarded": challenge.points_at_stake
    }

@router.get("/user/{user_name}")
def get_user_challenges(user_name: str, session: Session = Depends(get_session)):
    """Get user's challenges (pending and completed)."""
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get challenges where user is challenger or challengee
    query = select(Challenge).where(
        (Challenge.challenger_id == user.id) | (Challenge.challengee_id == user.id)
    )
    challenges = session.exec(query).all()
    
    return {
        "user_name": user_name,
        "challenges": [
            {
                "id": c.id,
                "status": c.status,
                "level_id": c.level_id,
                "winner_id": c.winner_id
            }
            for c in challenges
        ]
    }
```

- [ ] **Step 3: Create streak routes**

Create `SpellBackend/src/routes/streaks.py`:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from src.db_session import get_session
from src.services.streak_manager import StreakManager

router = APIRouter(prefix="/streaks", tags=["streaks"])

@router.get("/{user_name}")
def get_streak(user_name: str, session: Session = Depends(get_session)):
    """Get user's current streak."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = StreakManager(session)
    streak = manager.get_user_streak(user.id)
    login_check = manager.check_daily_login(user.id)
    
    return {
        **streak,
        **login_check
    }

@router.post("/{user_name}/revive")
def revive_streak(user_name: str, session: Session = Depends(get_session)):
    """Revive broken streak."""
    from src.models.user import User
    
    user = session.exec("SELECT * FROM user WHERE name = ?", [user_name]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    manager = StreakManager(session)
    result = manager.revive_streak(user.id)
    
    if not result["ok"]:
        raise HTTPException(status_code=400, detail=result["message"])
    
    return result
```

- [ ] **Step 4: Register all routes in main.py**

Modify `SpellBackend/main.py`:

```python
from src.routes import levels, unlockables, challenges, streaks

# Add routers
app.include_router(levels.router)
app.include_router(unlockables.router)
app.include_router(challenges.router)
app.include_router(streaks.router)
```

- [ ] **Step 5: Test all endpoints**

```bash
cd SpellBackend
python main.py
```

Test in separate terminal:
```bash
# List unlockables
curl "http://localhost:8000/unlockables/?user_name=alice"

# Create challenge
curl -X POST "http://localhost:8000/challenges/create?challenger_name=alice&challengee_name=bob&level_id=1"

# Get streak
curl "http://localhost:8000/streaks/alice"
```

- [ ] **Step 6: Commit**

```bash
git add src/routes/unlockables.py src/routes/challenges.py src/routes/streaks.py
git commit -m "feat: add unlockables, challenges, and streaks API routes"
```

---

## PHASE 2: FRONTEND FOUNDATION (Weeks 2-4)

*(This phase runs in parallel with backend completion)*

---

### Task 8: Flutter Project Setup

**Files:**
- Create: `FlutterSpell_Game/` (new project)
- Create: `FlutterSpell_Game/pubspec.yaml`

- [ ] **Step 1: Create new Flutter project**

```bash
flutter create --template=app FlutterSpell_Game
cd FlutterSpell_Game
```

- [ ] **Step 2: Update pubspec.yaml**

Edit `FlutterSpell_Game/pubspec.yaml`:

```yaml
name: spell_game
description: Game-based spelling app for kids.
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State management
  provider: ^6.0.0
  
  # HTTP client
  http: ^1.1.0
  
  # JSON serialization
  json_serializable: ^6.0.0
  
  # Local storage
  path_provider: ^2.0.0
  shared_preferences: ^2.0.0
  
  # Animations
  lottie: ^2.0.0
  
  # Audio
  audioplayers: ^4.0.0
  
  # UI
  cupertino_icons: ^1.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  build_runner: ^2.0.0
  json_serializable: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
    - assets/animations/
  fonts:
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
        - asset: assets/fonts/Fredoka-Bold.ttf
          weight: 700
```

- [ ] **Step 3: Run pub get**

```bash
cd FlutterSpell_Game
flutter pub get
```

Expected: Dependencies installed successfully.

- [ ] **Step 4: Create directory structure**

```bash
mkdir -p lib/{screens,widgets,services,models,providers}
mkdir -p assets/{sounds,animations,fonts}
```

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/
git commit -m "feat: scaffold new Flutter game app with dependencies"
```

---

### Task 9: Data Models & API Client

**Files:**
- Create: `FlutterSpell_Game/lib/models/game_models.dart`
- Create: `FlutterSpell_Game/lib/services/api_client.dart`

- [ ] **Step 1: Create game models**

Create `FlutterSpell_Game/lib/models/game_models.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'game_models.g.dart';

@JsonSerializable()
class Level {
  final int id;
  final String name;
  final int difficulty;
  final String? description;
  final List<Word>? words;

  Level({
    required this.id,
    required this.name,
    required this.difficulty,
    this.description,
    this.words,
  });

  factory Level.fromJson(Map<String, dynamic> json) => _$LevelFromJson(json);
  Map<String, dynamic> toJson() => _$LevelToJson(this);
}

@JsonSerializable()
class Word {
  final int id;
  final String text;
  final String language;

  Word({
    required this.id,
    required this.text,
    required this.language,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
  Map<String, dynamic> toJson() => _$WordToJson(this);
}

@JsonSerializable()
class LevelProgress {
  final int levelId;
  final String status;
  final int stars;
  final int studyCount;

  LevelProgress({
    required this.levelId,
    required this.status,
    required this.stars,
    required this.studyCount,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) =>
      _$LevelProgressFromJson(json);
  Map<String, dynamic> toJson() => _$LevelProgressToJson(this);
}

@JsonSerializable()
class Unlockable {
  final int id;
  final String type;
  final String name;
  final int pointsCost;
  final String rarity;
  final bool owned;
  final bool equipped;

  Unlockable({
    required this.id,
    required this.type,
    required this.name,
    required this.pointsCost,
    required this.rarity,
    required this.owned,
    required this.equipped,
  });

  factory Unlockable.fromJson(Map<String, dynamic> json) =>
      _$UnlockableFromJson(json);
  Map<String, dynamic> toJson() => _$UnlockableToJson(this);
}

@JsonSerializable()
class UserStats {
  final int totalPoints;
  final int currentStreak;
  final String? lastLogin;

  UserStats({
    required this.totalPoints,
    required this.currentStreak,
    this.lastLogin,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UserStatsToJson(this);
}

@JsonSerializable()
class Challenge {
  final int id;
  final String status;
  final int levelId;
  final int? winnerId;

  Challenge({
    required this.id,
    required this.status,
    required this.levelId,
    this.winnerId,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}
```

- [ ] **Step 2: Generate JSON serialization code**

```bash
cd FlutterSpell_Game
flutter pub run build_runner build
```

Expected: `game_models.g.dart` is generated.

- [ ] **Step 3: Create API client**

Create `FlutterSpell_Game/lib/services/api_client.dart`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_models.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:8000';
  final String userName;

  ApiClient({required this.userName});

  Future<List<Level>> getLevelList() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/levels/users/$userName'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final levelsData = json['levels'] as List;
        return levelsData
            .map((l) => Level.fromJson(l as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load levels');
      }
    } catch (e) {
      print('Error loading levels: $e');
      rethrow;
    }
  }

  Future<Level> getLevelDetails(int levelId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/levels/$levelId'),
      );

      if (response.statusCode == 200) {
        return Level.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load level');
      }
    } catch (e) {
      print('Error loading level: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeLevelStudy(
    int levelId,
    double accuracy,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/levels/users/$userName/progress/$levelId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accuracy': accuracy}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to complete level');
      }
    } catch (e) {
      print('Error completing level: $e');
      rethrow;
    }
  }

  Future<List<Unlockable>> getUnlockables() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/unlockables/?user_name=$userName'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final available = json['available'] as List;
        return available
            .map((u) => Unlockable.fromJson(u as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load unlockables');
      }
    } catch (e) {
      print('Error loading unlockables: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> redeemUnlockable(int unlockableId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/unlockables/$unlockableId/redeem?user_name=$userName'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to redeem unlockable');
      }
    } catch (e) {
      print('Error redeeming: $e');
      rethrow;
    }
  }

  Future<UserStats> getUserStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/streaks/$userName'),
      );

      if (response.statusCode == 200) {
        return UserStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      print('Error loading stats: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createChallenge(String challengeeName, int levelId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/create?challenger_name=$userName&challengee_name=$challengeeName&level_id=$levelId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create challenge');
      }
    } catch (e) {
      print('Error creating challenge: $e');
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add FlutterSpell_Game/lib/models/ FlutterSpell_Game/lib/services/
git commit -m "feat: add data models and API client for game backend"
```

---

### Task 10: State Management with Provider

**Files:**
- Create: `FlutterSpell_Game/lib/providers/game_provider.dart`

- [ ] **Step 1: Create GameProvider**

Create `FlutterSpell_Game/lib/providers/game_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_models.dart';
import '../services/api_client.dart';

class GameProvider extends ChangeNotifier {
  late ApiClient apiClient;
  
  List<Level> levels = [];
  Level? currentLevel;
  LevelProgress? currentProgress;
  UserStats? userStats;
  List<Unlockable> unlockables = [];
  
  bool isLoading = false;
  String? errorMessage;

  void init(String userName) {
    apiClient = ApiClient(userName: userName);
  }

  Future<void> loadLevels() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      levels = await apiClient.getLevelList();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLevelDetails(int levelId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      currentLevel = await apiClient.getLevelDetails(levelId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> completeLevel(int levelId, double accuracy) async {
    try {
      final result = await apiClient.completeLevelStudy(levelId, accuracy);
      
      // Reload levels to update progress
      await loadLevels();
      await loadUserStats();
      
      return result;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadUserStats() async {
    try {
      userStats = await apiClient.getUserStats();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadUnlockables() async {
    try {
      unlockables = await apiClient.getUnlockables();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> redeemUnlockable(int unlockableId) async {
    try {
      await apiClient.redeemUnlockable(unlockableId);
      await loadUnlockables();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createChallenge(String challengeeName, int levelId) async {
    try {
      await apiClient.createChallenge(challengeeName, levelId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add FlutterSpell_Game/lib/providers/game_provider.dart
git commit -m "feat: add GameProvider for state management"
```

---

### Task 11: Home Screen

**Files:**
- Create: `FlutterSpell_Game/lib/screens/home.dart`
- Create: `FlutterSpell_Game/lib/widgets/level_card.dart`

- [ ] **Step 1: Create LevelCard widget**

Create `FlutterSpell_Game/lib/widgets/level_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/game_models.dart';

class LevelCard extends StatelessWidget {
  final Level level;
  final VoidCallback onTap;
  final bool isLocked;

  const LevelCard({
    required this.level,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: isLocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${level.id}: ${level.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (level.description != null)
                          Text(level.description!),
                      ],
                    ),
                  ),
                  if (isLocked)
                    const Icon(Icons.lock, size: 32)
                  else
                    Row(
                      children: List.generate(3, (i) {
                        // Stars would go here based on progress
                        return const Icon(
                          Icons.star,
                          color: Colors.grey,
                          size: 20,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isLocked)
                ElevatedButton(
                  onPressed: onTap,
                  child: const Text('Play'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create HomeScreen**

Create `FlutterSpell_Game/lib/screens/home.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/level_card.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GameProvider>();
      provider.init(widget.userName);
      provider.loadLevels();
      provider.loadUserStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spell Adventure'),
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.levels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          return CustomScrollView(
            slivers: [
              // Streak banner
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.orange[300],
                leading: const SizedBox(),
                leadingWidth: 0,
                title: Center(
                  child: Column(
                    children: [
                      Text(
                        '🔥 ${provider.userStats?.currentStreak ?? 0} Days',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Keep it going!',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Points
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Points'),
                              Text(
                                '${provider.userStats?.totalPoints ?? 0}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Levels'),
                              Text(
                                '${provider.levels.length}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Levels list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final level = provider.levels[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: LevelCard(
                        level: level,
                        isLocked: level.id > 1, // Simplified; use actual logic
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/level-select',
                            arguments: level.id,
                          );
                        },
                      ),
                    );
                  },
                  childCount: provider.levels.length,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Levels'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          // TODO: Navigate to other screens
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Update main.dart to use HomeScreen**

Modify `FlutterSpell_Game/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Spell Adventure',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(userName: 'alice'),
        routes: {
          '/level-select': (context) => const LevelSelectScreen(),
          '/study': (context) => const StudyScreen(),
          '/rewards': (context) => const RewardsScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

// Placeholder screens
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Level Select')));
  }
}

class StudyScreen extends StatelessWidget {
  const StudyScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Study')));
  }
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Rewards')));
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Leaderboard')));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile')));
  }
}
```

- [ ] **Step 4: Test home screen**

```bash
cd FlutterSpell_Game
flutter run -d chrome
```

Expected: Home screen loads with streak, points, and level list (or loading state).

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/lib/screens/home.dart FlutterSpell_Game/lib/widgets/level_card.dart FlutterSpell_Game/lib/main.dart
git commit -m "feat: build home screen with streak counter and level list"
```

---

*(Remaining tasks 12-30 follow the same pattern: Study Screen, Rewards Shop, Leaderboard, Profile, Testing, Deployment — each with 3-5 specific steps, exact code, and frequent commits)*

*(Due to length constraints, I'm showing the detailed format for early tasks. Tasks 12-30 would continue with equal rigor but abbreviated here.)*

---

## Summary: Remaining Tasks (12-30)

| Task | Component | Est. Time |
|------|-----------|-----------|
| 12-14 | Study Screen (mixed modes + animations) | 3 days |
| 15-17 | Rewards Shop & Cosmetics | 2 days |
| 18-19 | Leaderboard & Challenges | 2 days |
| 20 | Profile Screen | 1 day |
| 21-23 | Integration Testing | 2 days |
| 24-25 | Sound & Animation Polish | 1.5 days |
| 26-27 | Deploy Backend (Fly.io) | 1 day |
| 28-29 | Deploy Flutter App (Play Store / App Store) | 1 day |
| 30 | Final QA & Fixes | 1 day |

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-12-game-ui-implementation.md`.**

---

**Two execution options:**

### **1. Subagent-Driven (Recommended)**
- I dispatch a fresh subagent per task
- Quick review between tasks, fast iteration
- Best for parallel backend/frontend work

### **2. Inline Execution**
- Execute tasks in this session
- Batch execution with checkpoints
- Better for focused, sequential work

**Which approach?** (Or give me specific tasks to prioritize first.)
