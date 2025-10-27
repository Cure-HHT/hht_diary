"use strict";
/**
 * GraphQL queries for Linear API
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.GET_USER_INFO = exports.GET_IN_PROGRESS_ISSUES = void 0;
exports.GET_IN_PROGRESS_ISSUES = `
  query GetInProgressIssues {
    viewer {
      id
      name
      email
      assignedIssues(
        filter: {
          state: { name: { in: ["In Progress", "In Review"] } }
        }
        orderBy: updatedAt
      ) {
        nodes {
          id
          identifier
          title
          description
          url
          state {
            name
          }
          comments {
            nodes {
              id
              body
              createdAt
            }
          }
        }
      }
    }
  }
`;
exports.GET_USER_INFO = `
  query GetUserInfo {
    viewer {
      id
      name
      email
    }
  }
`;
//# sourceMappingURL=queries.js.map