import PropTypes from 'prop-types'

export default function LoadingState({ label = 'Loading…' }) {
  return <output className="state">{label}</output>
}

LoadingState.propTypes = {
  label: PropTypes.string,
}
