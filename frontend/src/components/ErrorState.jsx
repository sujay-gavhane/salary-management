import PropTypes from 'prop-types'
import { apiErrorMessage } from '../api/errors.js'

export default function ErrorState({ error, onRetry }) {
  return (
    <div role="alert" className="state state--error">
      <p>{apiErrorMessage(error)}</p>
      {onRetry && (
        <button type="button" className="button" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  )
}

ErrorState.propTypes = {
  error: PropTypes.object,
  onRetry: PropTypes.func,
}
