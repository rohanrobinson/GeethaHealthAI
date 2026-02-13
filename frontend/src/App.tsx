import { useState } from 'react'
import { Link, Route, Routes, useNavigate } from 'react-router-dom'
import './App.css'
import About from './About.tsx'
import CreateFamily from './CreateFamily.tsx'
import FamilyProfile from './FamilyProfile.tsx'
import MemberProfile from './MemberProfile.tsx'

function Navbar() {
  return (
    <header className="navbar">
      <Link to="/" className="navbar-brand">
        Geetha Health
      </Link>
      <nav className="navbar-links" aria-label="Primary">
        <span>My Account</span>
        <Link to="/about">
          About
        </Link>
      </nav>
    </header>
  )
}

function Home() {
  const [isLoginOpen, setIsLoginOpen] = useState(false)
  const navigate = useNavigate()

  const handleContinue = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsLoginOpen(false)
    navigate('/create-family')
  }

  return (
    <>
      <h1>Stay on top of your Family's Healthcare</h1>
      <h2>Track medications, appointments, and conditions for everyone you love.</h2>
      <div className="card">
        <button onClick={() => setIsLoginOpen(true)}>Get Started</button>
      </div>

      {isLoginOpen ? (
        <div
          className="modal-backdrop"
          onClick={() => setIsLoginOpen(false)}
        >
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="login-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="modal-header">
              <h3 id="login-title">Login</h3>
              <button
                className="modal-close"
                onClick={() => setIsLoginOpen(false)}
                aria-label="Close login modal"
              >
                ✕
              </button>
            </div>
            <form className="modal-body" onSubmit={handleContinue}>
              <label className="field">
                Email
                <input type="email" placeholder="rohan@geethahealth.com" />
              </label>
              <label className="field">
                Password
                <input type="password" placeholder="••••••••" />
              </label>
              <button type="submit" className="primary">
                Continue
              </button>
            </form>
          </div>
        </div>
      ) : null}
    </>
  )
}

function App() {
  return (
    <>
      <Navbar />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/create-family" element={<CreateFamily />} />
        <Route path="/family-profile" element={<FamilyProfile />} />
        <Route path="/member-profile/:memberId" element={<MemberProfile />} />
        <Route path="/about" element={<About />} />
      </Routes>
    </>
  )
}

export default App
