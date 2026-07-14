package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var envCmd = &cobra.Command{
	Use:   "env",
	Short: "Manage environments",
}

var envListCmd = &cobra.Command{
	Use:   "list",
	Short: "List environments",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Listing environments...")
	},
}

var envStatusCmd = &cobra.Command{
	Use:   "status [environment]",
	Short: "Check environment status",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Status for environment: %s\n", args[0])
	},
}

func init() {
	envCmd.AddCommand(envListCmd)
	envCmd.AddCommand(envStatusCmd)
	rootCmd.AddCommand(envCmd)
}
