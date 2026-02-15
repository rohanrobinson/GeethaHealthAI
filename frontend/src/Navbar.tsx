import { Link } from 'react-router-dom'

function Navbar() {
  return (
    <header className="navbar">
      <Link to="/" className="navbar-brand">
        Geetha Health
      </Link>
      <nav className="navbar-links" aria-label="Primary">
        <div className="navbar-dropdown">
          <span className="navbar-dropdown-trigger" aria-haspopup="true" aria-expanded="false">
            My Account
          </span>
          <div className="navbar-dropdown-menu" role="menu">
            <Link to="/family-profile" role="menuitem" className="navbar-dropdown-item">
              Family Profile
            </Link>
            <Link to="/documents" role="menuitem" className="navbar-dropdown-item">
              Documents
            </Link>
          </div>
        </div>
        <Link to="/about">About</Link>
      </nav>
    </header>
  )
}

export default Navbar
